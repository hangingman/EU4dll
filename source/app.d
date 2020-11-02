import std.stdio;

int sum(int a, int b)
{
    return a+b;
}


unittest
{
    assert(sum(3,4) == 7);
}
