const std = @import("std");
const math = std.math;

pub const Vector3 = @Vector(3, f32);

pub const Material = @import("types/Material.zig").Material;
pub const Sphere = @import("types/Sphere.zig").Sphere;

pub fn degrees_to_radians(degree: f32) f32 {
    return degree * math.pi / 180.0;
}
