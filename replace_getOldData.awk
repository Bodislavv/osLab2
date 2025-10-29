#!/usr/bin/awk -f

function next_nonspace_or_comment(t, pos,   n,c,c2,p){
  n = length(t)
  while (pos <= n) {
    c  = substr(t,pos,1)
    c2 = (pos < n) ? substr(t,pos,2) : ""
    if (c ~ /[ \t\r\n]/) { pos++; continue }
    if (c2 == "//") {
      p = index(substr(t,pos), "\n")
      if (p == 0) return n+1
      pos += p
      continue
    }
    if (c2 == "/*") {
      p = index(substr(t,pos+2), "*/")
      if (p == 0) return n+1
      pos = pos + 2 + p + 2
      continue
    }
    break
  }
  return pos
}

function copy_line_comment(t, i,   p){
  p = index(substr(t,i), "\n")
  if (p == 0) { out = out substr(t,i); return length(t)+1 }
  out = out substr(t,i,p)
  return i + p
}

function copy_block_comment(t, i,   p,endpos){
  p = index(substr(t,i+2), "*/")
  if (p == 0) { out = out substr(t,i); return length(t)+1 }
  endpos = i + 2 + p + 1
  out = out substr(t,i, endpos - i + 0)
  return endpos + 1
}

function copy_string_dq(t, i,   n,j,c){
  n = length(t); out = out substr(t,i,1); j = i+1
  while (j <= n) {
    c = substr(t,j,1)
    out = out c
    if (c == "\\") { if (j < n) { j++; out = out substr(t,j,1) } j++; continue }
    if (c == "\"") { j++; break }
    j++
  }
  return j
}

function copy_string_sq(t, i,   n,j,c){
  n = length(t); out = out substr(t,i,1); j = i+1
  while (j <= n) {
    c = substr(t,j,1)
    out = out c
    if (c == "\\") { if (j < n) { j++; out = out substr(t,j,1) } j++; continue }
    if (c == "'") { j++; break }
    j++
  }
  return j
}

{
  S = S $0 "\n"
}

END{
  name = "getOldData"; repl = "fetchData"
  n = length(S); i = 1; out = ""
  while (i <= n) {
    c  = substr(S,i,1)
    c2 = (i < n) ? substr(S,i,2) : ""

    if (c2 == "//") { i = copy_line_comment(S,i); continue }
    if (c2 == "/*") { i = copy_block_comment(S,i); continue }
    if (c == "\"") { i = copy_string_dq(S,i); continue }
    if (c == "'")  { i = copy_string_sq(S,i); continue }

    if (substr(S,i,length(name)) == name) {
      prev = (i>1)? substr(S,i-1,1) : ""
      nextc = substr(S, i+length(name), 1)
      if (!(prev ~ /[A-Za-z0-9_]/) && !(nextc ~ /[A-Za-z0-9_]/)) {
        j = next_nonspace_or_comment(S, i+length(name))
        if (j <= n && substr(S,j,1) == "(") {
          out = out repl
          i = i + length(name)
          continue
        }
      }
    }

    out = out c
    i++
  }
  printf "%s", out
}