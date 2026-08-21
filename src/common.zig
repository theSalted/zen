const std = @import("std");
const math = std.math;

pub const Vector3 = @Vector(3, f32);

pub const Material = @import("types/Material.zig").Material;
pub const Sphere = @import("types/Sphere.zig").Sphere;

pub fn degrees_to_radians(degree: f32) f32 {
    return degree * math.pi / 180.0;
}

pub fn normalize(v: Vector3) Vector3 {
    const len = @sqrt(@reduce(.Add, v * v));

    if (len == 0.0) {
        return v;
    }

    return v / @as(Vector3, @splat(len));
}

pub fn cross(a: Vector3, b: Vector3) Vector3 {
    return .{
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    };
}
