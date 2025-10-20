#include <iostream>

namespace ns {
    int getOldData(int a) { return a; }
}

class Class {
public:
    static int getOldData(int b) { return b; }
};

int main() {
    // Line comment with getOldData
    std::string s = "getOldData()";  // String literal with getOldData
    /* Block comment with getOldData */

    int x = getOldData(1);  // Unqualified call

    int y = ns::getOldData (2);  // Qualified with space before (

    int z = Class :: getOldData/*comment here*/(3);  // Qualified with spaces around :: and comment before (

    int w = ::getOldData(4);  // Global with leading ::

    int v = ns :: sub :: getOldData /*c1*/ /*c2*/ (5);  // Multi-qualifier with spaces and multiple comments before (

    // Non-target: obj.getOldData(6);  // Instance member (uses . not ::, won't match)

    // 1) Instance call via dot (should NOT change)
    struct Obj { int getOldData(int); } obj;
    int i1 = obj.getOldData(10);

    // 2) Definition with brace on next line (should NOT change)
    int getOldData
    (
      int a
    )
    {
      return a;
    }

    // 3) Multiple block comments right before (
    int i2 = ns :: sub :: getOldData /*c1*/ /*c2*/(42);

    // 4) Template-like call (likely NOT changed by current logic)
    int i3 = ns::getOldData<int>(5);

    // 5) Char literals (should NOT change)
    char chs[] = {'g','e','t','O','l','d','D','a','t','a'};

    return 0;
}
