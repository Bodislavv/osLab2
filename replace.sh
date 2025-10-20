#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <file.cpp>"
    exit 1
fi

file="$1"

# Validate input file
if [ ! -f "$file" ]; then
    echo "Error: file not found: $file"
    exit 1
fi

# Create a timestamped backup before modifying
timestamp="$(date +%Y%m%d%H%M%S)"
backup_file="${file}.bak.${timestamp}"
cp -- "$file" "$backup_file" || { echo "Error: failed to create backup at $backup_file"; exit 1; }
echo "Backup created: $backup_file"

tmp_file="$(mktemp)"

awk -v SQUOTE="'" '
BEGIN {
    name = "getOldData"
    replacement = "fetchData"
}
{
    line = $0
    out = ""
    i = 1
    len = length(line)
    in_line_comment = 0
    while (i <= len) {
        c = substr(line, i, 1)

        # Handle existing block comment state across lines
        if (in_block_comment) {
            if (i < len && substr(line, i, 2) == "*/") {
                out = out "*/"
                in_block_comment = 0
                i += 2
                continue
            }
            out = out c
            i++
            continue
        }

        # Handle string state
        if (in_string) {
            if (c == "\\" && i < len) {
                out = out substr(line, i, 2)
                i += 2
                continue
            }
            out = out c
            if (c == "\"") in_string = 0
            i++
            continue
        }

        # Handle character literal state
        if (in_char) {
            if (c == "\\" && i < len) {
                out = out substr(line, i, 2)
                i += 2
                continue
            }
            out = out c
            if (c == SQUOTE) in_char = 0
            i++
            continue
        }

        # Enter line or block comments
        if (i < len && substr(line, i, 2) == "//") {
            out = out substr(line, i)
            break
        }
        if (i < len && substr(line, i, 2) == "/*") {
            out = out "/*"
            in_block_comment = 1
            i += 2
            continue
        }

        # Enter string or char literal
        if (c == "\"") { in_string = 1; out = out c; i++; continue }
        if (c == SQUOTE) { in_char = 1; out = out c; i++; continue }

        # Try to match the function name in code
        if (substr(line, i, length(name)) == name) {
            # Word boundaries
            prev = (i > 1) ? substr(line, i-1, 1) : ""
            nextc = (i+length(name) <= len) ? substr(line, i+length(name), 1) : ""
            if (prev ~ /[A-Za-z0-9_]/ || nextc ~ /[A-Za-z0-9_]/) {
                out = out c; i++; continue
            }

            # Ensure previous non-space is not a dot (to avoid obj.getOldData)
            bi = i - 1
            while (bi >= 1) {
                ch = substr(line, bi, 1)
                if (ch ~ /[ \t]/) { bi--; continue }
                break
            }
            prev_ns = (bi >= 1) ? substr(line, bi, 1) : ""
            if (prev_ns == ".") { out = out c; i++; continue }

            # Look ahead for opening parenthesis, skipping spaces and block comments
            j = i + length(name)
            while (j <= len) {
                ch = substr(line, j, 1)
                if (ch ~ /[ \t]/) { j++; continue }
                if (j < len && substr(line, j, 2) == "/*") {
                    j += 2
                    while (j < len && substr(line, j, 2) != "*/") { j++ }
                    if (j < len) j += 2
                    continue
                }
                break
            }
            if (j <= len && substr(line, j, 1) == "(") {
                # Try to distinguish call from definition on the same line:
                # find matching closing paren and check for a following '{' (after spaces/comments)
                depth = 0
                k = j
                while (k <= len) {
                    ch2 = substr(line, k, 1)
                    if (ch2 == "(") depth++
                    else if (ch2 == ")") { depth--; if (depth == 0) { k++; break } }
                    k++
                }
                m = k
                while (m <= len) {
                    ch3 = substr(line, m, 1)
                    if (ch3 ~ /[ \t]/) { m++; continue }
                    if (m < len && substr(line, m, 2) == "/*") {
                        m += 2
                        while (m < len && substr(line, m, 2) != "*/") { m++ }
                        if (m < len) m += 2
                        continue
                    }
                    break
                }
                if (m <= len) {
                    next_token = substr(line, m, 1)
                    if (next_token == "{") {
                        # Likely a definition – do not replace
                        out = out substr(line, i, length(name))
                        i += length(name)
                        continue
                    }
                    if (next_token == ";") {
                        # Heuristic: decide between call statement and prototype/declaration
                        # Look backwards from the function name for a preceding word/token
                        bi2 = i - 1
                        while (bi2 >= 1 && substr(line, bi2, 1) ~ /[ \t]/) bi2--
                        # Skip potential :: qualifiers backwards
                        while (bi2 >= 2 && substr(line, bi2-1, 2) == "::") {
                            bi2 -= 2
                            while (bi2 >= 1 && substr(line, bi2, 1) ~ /[ \t]/) bi2--
                            # consume the preceding identifier
                            while (bi2 >= 1 && substr(line, bi2, 1) ~ /[A-Za-z0-9_]/) bi2--
                            while (bi2 >= 1 && substr(line, bi2, 1) ~ /[ \t]/) bi2--
                        }
                        # Gather previous identifier (if any)
                        endw = bi2
                        while (bi2 >= 1 && substr(line, bi2, 1) ~ /[A-Za-z0-9_]/) bi2--
                        startw = bi2 + 1
                        prevWord = (startw <= endw) ? substr(line, startw, endw - startw + 1) : ""
                        # Check for pointer/ref symbols just before the word
                        ptrsym = (bi2 >= 1 && substr(line, bi2, 1) ~ /[\*&]/) ? 1 : 0
                        # Also detect clear call-context symbols right before name
                        callctx = 0
                        tmpi = i - 1
                        while (tmpi >= 1 && substr(line, tmpi, 1) ~ /[ \t]/) tmpi--
                        if (tmpi >= 1 && substr(line, tmpi, 1) ~ /[=\(,]/) callctx = 1

                        if (!callctx && (ptrsym || prevWord ~ /^(int|void|float|double|char|short|long|unsigned|signed|static|constexpr|const|virtual|inline|friend|volatile|auto|bool|typename|class|struct)$/)) {
                            # Looks like a declaration/prototype – do not replace
                            out = out substr(line, i, length(name))
                            i += length(name)
                            continue
                        }
                        # Otherwise, treat as a call (e.g., assignment or expression statement)
                    }
                }
                # Consider this a call – replace name
                out = out replacement
                i += length(name)
                continue
            }
        }

        # Default: copy current character
        out = out c
        i++
    }
    print out
}' "$file" > "$tmp_file" && mv "$tmp_file" "$file"