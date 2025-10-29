#include <string>
#include <iostream>

namespace ns {
int value() { return 42; }
}

struct Foo {
    int x = 0;
    int getOldData_member() const { return 7; } // unrelated name, should stay
    int fetchData() const { return 1; } // definition present only to test that we don't touch calls vs other names
};

int main() {
    // Calls we SHOULD replace
    int a = fetchData   /*block*/  ();
    int b = fetchData // line comment before paren
    (1, 2);

    Foo obj;
    int c = obj.fetchData	 (3);

    Foo* ptr = &obj;
    int d = ptr->fetchData /* c */(4);

    int e = ns::fetchData   (5);
    int f = Foo::fetchData /*c*/(6);

    // Things we MUST NOT replace
    std::string s1 = "getOldData(123)"; // in string
    std::string s2 = R"( getOldData ( in raw string ) )"; // raw string
    // getOldData(999); // in comment only

    // Unrelated similar identifiers must remain
    int getOldDataValue = 10; // not a call
    int r1 = getOldDataValue; // read variable, not a call
    int r2 = obj.getOldData_member(); // different name

    std::cout << a+b+c+d+e+f+r1+r2 << "\n";
    return 0;
}


