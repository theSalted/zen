const common = @import("../common.zig");

pub const Material = extern struct {
    type: Type,
    albedo: common.Vector3 = .{ 1.0, 1.0, 1.0 },
    fuzz: f32 = 0.0,
    refraction_index: f32 = 0.0,

    pub const Type = enum(u32) {
        Lambertian = 0,
        Metal = 1,
        Dialectric = 2,
    };
};
