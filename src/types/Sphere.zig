const common = @import("../common.zig");

pub const Sphere = extern struct {
    center: common.Vector3,
    radius: f32,
    material_index: u32,
};
