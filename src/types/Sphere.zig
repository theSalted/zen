const common = @import("../common.zig");
const Ray = @import("Ray.zig").Ray;
const AABB = @import("AABB.zig").AABB;

pub const Sphere = extern struct {
    center: Ray,
    radius: f32,
    material_index: u32,
    bbox: AABB,

    pub fn stationary(center: common.Vector3, radius: f32, material_index: u32) Sphere {
        const rvec = @Vector(3, f32){ radius, radius, radius };
        return .{
            .center = .{
                .origin = center,
                .direction = .{ 0.0, 0.0, 0.0 },
                .time = 0.0,
            },
            .radius = radius,
            .material_index = material_index,
            .bbox = AABB.initFromPoints(center - rvec, center + rvec),
        };
    }

    pub fn moving(center1: common.Vector3, center2: common.Vector3, radius: f32, material_index: u32) Sphere {
        const rvec = @Vector(3, f32){ radius, radius, radius };
        const center: Ray = .{
            .origin = center1,
            .direction = center2 - center1,
            .time = 0.0,
        };

        const bbox1: AABB = .initFromPoints(center.at(0.0) - rvec, center.at(0.0) + rvec);
        const bbox2: AABB = .initFromPoints(center.at(1.0) - rvec, center.at(1.0) + rvec);
        return .{
            .center = .{
                .origin = center1,
                .direction = center2 - center1,
                .time = 0.0,
            },
            .radius = radius,
            .material_index = material_index,
            .bbox = AABB.initFromAABB(bbox1, bbox2),
        };
    }
};
