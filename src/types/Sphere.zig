const common = @import("../common.zig");
const Ray = @import("Ray.zig").Ray;

pub const Sphere = extern struct {
    center: Ray,
    radius: f32,
    material_index: u32,

    pub fn stationary(center: common.Vector3, radius: f32, material_index: u32) Sphere {
        return .{
            .center = .{
                .origin = center,
                .direction = .{ 0.0, 0.0, 0.0 },
                .time = 0.0,
            },
            .radius = radius,
            .material_index = material_index,
        };
    }

    pub fn moving(center1: common.Vector3, center2: common.Vector3, radius: f32, material_index: u32) Sphere {
        return .{
            .center = .{
                .origin = center1,
                .direction = center2 - center1,
                .time = 0.0,
            },
            .radius = radius,
            .material_index = material_index,
        };
    }
};
