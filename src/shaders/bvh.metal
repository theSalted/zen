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
    uint lhs;
    uint rhs;
    uint sphere_index;
    uint kind; // 0 == leaf, 1 == branch`
};
