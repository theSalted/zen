pub const AABB = @import("AABB.zig").AABB;

pub const Ref = extern struct {
    kind: Kind,
    index: u32,

    pub const Kind = enum(u32) {
        node = 0,
        none = 1,
        sphere = 2,
    };
};

pub const BVHNode = extern struct {
    bbox: AABB,
    lhs: Ref,
    rhs: Ref,
};
