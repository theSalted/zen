const common = @import("../common.zig");

pub const Ray = extern struct {
    origin: common.Vector3,
    direction: common.Vector3,
    time: f32,

    pub fn at(self: Ray, t: f32) common.Vector3 {
        return self.origin + @as(common.Vector3, @splat(t)) * self.direction;
    }
};
