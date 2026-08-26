const std = @import("std");
const Sphere = @import("Sphere.zig").Sphere;
const Material = @import("Material.zig").Material;
const AABB = @import("AABB.zig").AABB;
const BVHNode = @import("BVHNode.zig").BVHNode;
const Ref = @import("BVHNode.zig").Ref;

pub const Scene = struct {
    allocator: std.mem.Allocator,
    spheres: std.ArrayList(Sphere),
    materials: std.ArrayList(Material),
    bvh_nodes: std.ArrayList(BVHNode),
    bbox: AABB,
    root_node: u32,

    pub fn init(allocator: std.mem.Allocator) Scene {
        return .{
            .allocator = allocator,
            .spheres = .empty,
            .materials = .empty,
            .bvh_nodes = .empty,
            .bbox = AABB.empty(),
            .root_node = undefined,
        };
    }

    pub fn buildBVH(self: *Scene) !void {
        const indices = try self.allocator.alloc(u32, self.spheres.items.len);
        defer self.allocator.free(indices);

        for (indices, 0..) |*index, i| {
            index.* = @intCast(i);
        }

        try self.buildRange(indices, 0, indices.len, &self.root_node);
    }

    fn buildRange(self: *Scene, refs: []Ref, start: usize, end: usize, out: *Ref) !void {
        const span = end - start;

        if (span == 1) {
            out.* = refs[start];
            return;
        }

        _ = self;
    }

    pub fn deinit(self: *Scene) void {
        self.spheres.deinit(self.allocator);
        self.materials.deinit(self.allocator);
        self.bvh_nodes.deinit(self.allocator);
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

    pub fn sortByAxis(scene: *const Scene, indices: []u32, axis: u32) void {
        const Context = struct {
            scene: *const Scene,
            axis: u32,

            fn lessThan(ctx: @This(), a: u32, b: u32) bool {
                const box1 = ctx.scene.spheres.items[a].bbox.axisInterval(ctx.axis);
                const box2 = ctx.scene.spheres.items[b].bbox.axisInterval(ctx.axis);
                return box1.min < box2.min;
            }
        };

        std.mem.sort(u32, indices, Context{ .scene = scene, .axis = axis }, Context.lessThan);
    }
};
