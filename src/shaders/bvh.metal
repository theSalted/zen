#include "aabb.metal"

enum Kind: uint {
    sphere, node
};

struct Ref {
    Kind kind;
    uint index;
};

struct BVHNode {
    AABB bbox;
    Ref lhs;
    Ref rhs;
};
