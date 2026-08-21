const std = @import("std");
const math = std.math;
const common = @import("../common.zig");

const Camera = @This();
const Vector3 = common.Vector3;

pub const ShaderInput = struct {
    camera_center: Vector3,
    pixel_delta_u: Vector3,
    pixel_delta_v: Vector3,
    defocus_angle: f32,
    focus_dist: f32,
    defocus_disk_u: Vector3,
    defocus_disk_v: Vector3,

    viewport_upper_left: Vector3,
    samples_per_pixel: u32,
    ray_depth: u32,
};

vfov: f32 = 90.0,
defocus_angle: f32 = 0.0,
focus_dist: f32 = 10.0,
samples_per_pixel: u32 = 30,
ray_depth: u32 = 10,

transform: Vector3 = .{ 0.0, 0.0, 0.0 },
lookat: Vector3 = .{ 0.0, 0.0, -1.0 },
vup: Vector3 = .{ 0.0, 1.0, 0.0 },

pub fn translate(camera: *Camera, delta: Vector3) void {
    camera.transform += delta;
    camera.lookat += delta;
}

pub fn rotate(camera: *Camera, yaw: f32, pitch: f32) void {
    const distance = focusDistance(camera.*);
    var direction = forward(camera.*);

    direction = rotateAroundAxis(direction, camera.vup, yaw);
    direction = rotateAroundAxis(direction, right(camera.*), pitch);

    camera.lookat = camera.transform + scale(common.normalize(direction), distance);
}

pub fn buildShaderInput(camera: Camera, image_width: u32, image_height: u32) ShaderInput {
    const aspect_ratio =
        @as(f32, @floatFromInt(image_width)) /
        @as(f32, @floatFromInt(image_height));
    const camera_center = camera.transform;
    const theta = common.degrees_to_radians(camera.vfov);
    const ih = math.tan(theta / 2);
    const viewport_height: f32 = 2.0 * ih * camera.focus_dist;
    const viewport_width = viewport_height * aspect_ratio;

    const w = common.normalize(camera.transform - camera.lookat);
    const u = common.normalize(common.cross(camera.vup, w));
    const v = common.cross(w, u);

    const viewport_u = @as(Vector3, @splat(viewport_width)) * u;
    const viewport_v = @as(Vector3, @splat(-viewport_height)) * v;

    const pixel_delta_u = viewport_u / @as(Vector3, @splat(@as(f32, @floatFromInt(image_width))));
    const pixel_delta_v = viewport_v / @as(Vector3, @splat(@as(f32, @floatFromInt(image_height))));
    const viewport_upper_left =
        camera_center -
        @as(Vector3, @splat(camera.focus_dist)) * w -
        viewport_u / @as(Vector3, @splat(2.0)) -
        viewport_v / @as(Vector3, @splat(2.0));

    const defocus_radius = camera.focus_dist * math.tan(common.degrees_to_radians(camera.defocus_angle / 2.0));
    const defocus_disk_u = u * @as(Vector3, @splat(defocus_radius));
    const defocus_disk_v = v * @as(Vector3, @splat(defocus_radius));

    return .{
        .camera_center = camera_center,
        .pixel_delta_u = pixel_delta_u,
        .pixel_delta_v = pixel_delta_v,
        .defocus_angle = camera.defocus_angle,
        .focus_dist = camera.focus_dist,
        .defocus_disk_u = defocus_disk_u,
        .defocus_disk_v = defocus_disk_v,
        .samples_per_pixel = camera.samples_per_pixel,
        .ray_depth = camera.ray_depth,
        .viewport_upper_left = viewport_upper_left,
    };
}

fn scale(v: Vector3, amount: f32) Vector3 {
    return v * @as(Vector3, @splat(amount));
}

fn dot(a: Vector3, b: Vector3) f32 {
    return @reduce(.Add, a * b);
}

fn forward(camera: Camera) Vector3 {
    return common.normalize(camera.lookat - camera.transform);
}

fn right(camera: Camera) Vector3 {
    return common.normalize(common.cross(forward(camera), camera.vup));
}

fn focusDistance(camera: Camera) f32 {
    const offset = camera.lookat - camera.transform;
    const distance = @sqrt(@reduce(.Add, offset * offset));

    if (distance == 0.0) {
        return 1.0;
    }

    return distance;
}

fn rotateAroundAxis(v: Vector3, axis: Vector3, angle: f32) Vector3 {
    const unit_axis = common.normalize(axis);
    const c = @cos(angle);
    const s = @sin(angle);

    return scale(v, c) +
        scale(common.cross(unit_axis, v), s) +
        scale(unit_axis, dot(unit_axis, v) * (1.0 - c));
}
