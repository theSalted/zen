const std = @import("std");
const Sphere = @import("Sphere.zig").Sphere;
const Material = @import("Material.zig").Material;
const AABB = @import("AABB.zig").AABB;

pub const Scene = struct {
    allocator: std.mem.Allocator,
    spheres: std.ArrayList(Sphere),
    materials: std.ArrayList(Material),
    bbox: AABB,

    pub fn init(allocator: std.mem.Allocator) Scene {
        return .{
            .allocator = allocator,
            .spheres = .empty,
            .materials = .empty,
            .bbox = AABB.empty(),
        };
    }

    pub fn deinit(self: *Scene) void {
        self.spheres.deinit(self.allocator);
        self.materials.deinit(self.allocator);
    }

    pub fn addSphere(self: *Scene, sphere: Sphere) !void {
        try self.spheres.append(self.allocator, sphere);
        self.bbox = AABB.initFromAABB(self.bbox, sphere.bbox);
    }

    pub fn addSpheres(self: *Scene, spheres: []const Sphere) !void {
        try self.spheres.appendSlice(self.allocator, spheres);

        for (spheres) |sphere| {
            self.bbox = AABB.initFromAABB(self.bbox, sphere.bbox);
        }
    }

    pub fn addMaterial(self: *Scene, material: Material) !u32 {
        const index: u32 = @intCast(self.materials.items.len);
        try self.materials.append(self.allocator, material);
        return index;
    }

    pub fn addMaterials(self: *Scene, materials: []const Material) !void {
        try self.materials.appendSlice(self.allocator, materials);
    }

    pub fn spheresCount(self: *const Scene) usize {
        return self.spheres.items.len;
    }

    pub fn materialsCount(self: *const Scene) usize {
        return self.materials.items.len;
    }
};
