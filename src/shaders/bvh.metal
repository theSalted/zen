#ifndef ZEN_BVH_METAL
#define ZEN_BVH_METAL

#include "aabb.metal"

enum Kind: uint {
    node, none, sphere
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

#endif
