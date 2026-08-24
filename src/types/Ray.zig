const common = @import("../common.zig");

pub const Ray = extern struct {
    origin: common.Vector3,
    direction: common.Vector3,
    time: f32,
};
