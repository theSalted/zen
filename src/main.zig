const std = @import("std");
const zen = @import("zen");
const metal = zen.graphics.metal;
const common = @import("common.zig");

const Vector3 = common.Vector3;
const Material = common.Material;
const Sphere = common.Sphere;
const Camera = @import("types/Camera.zig");

pub const RayTraceInput = extern struct {
    image_width: u32,
    image_height: u32,

    camera_center: Vector3,
    pixel_delta_u: Vector3,
    pixel_delta_v: Vector3,
    viewport_upper_left: Vector3,

    sphere_count: u32,
    material_count: u32,
};

pub fn main(init: std.process.Init) !void {
    _ = init;

    const width = 1280;
    const height = 720;
    const move_speed: f32 = 2.0;
    const mouse_sensitivity: f32 = 0.003;

    var camera = Camera{};
    var image_width: u32 = width;
    var image_height: u32 = height;
    var camera_control = CameraControl{};
    var last_frame_ns = zen.Runtime.ticksNS();

    var runtime = try zen.Runtime.init(width, height);
    defer runtime.deinit();

    const renderer = metal.Renderer.init(try runtime.metalLayer(), width, height) orelse
        return error.MetalCreateFailed;
    defer renderer.deinit();

    const library = metal.ShaderLibrary.init(renderer, "default.metallib") orelse
        return error.MetalShaderLibraryFailed;
    defer library.deinit();

    const render_pipeline = metal.RenderPipeline.init(renderer, library, "vertex_main", "fragment_main") orelse
        return error.MetalRenderPipelineFailed;
    defer render_pipeline.deinit();

    const compute_pipeline = metal.ComputePipeline.init(renderer, library, "ray_trace_kernel") orelse
        return error.MetalComputePipelineFailed;
    defer compute_pipeline.deinit();

    const image_desc = metal.TextureDesc{
        .width = width,
        .height = height,
        .format = .rgba8_unorm,
        .usage = @as(u32, @bitCast(metal.TextureUsage{
            .shader_read = true,
            .shader_write = true,
        })),
    };

    var image = metal.Texture.init(renderer, &image_desc) orelse {
        return error.MetalTextureFailed;
    };
    defer image.deinit();

    const param_buffer = metal.Buffer.init(renderer, RayTraceInput) orelse
        return error.MetalBufferFailed;
    defer param_buffer.deinit();

    const material_ground: Material = .{ .type = .Lambertian, .albedo = .{ 0.8, 0.8, 0.0 } };
    const material_center: Material = .{ .type = .Lambertian, .albedo = .{ 0.1, 0.2, 0.5 } };
    const material_left: Material = .{ .type = .Dialectric, .refraction_index = 1.50 };
    const material_right: Material = .{ .type = .Metal, .albedo = .{ 0.8, 0.6, 0.2 }, .fuzz = 1.0 };
    const material_bubble: Material = .{ .type = .Dialectric, .refraction_index = 1.00 / 1.50 };

    const materials = [_]Material{
        material_ground,
        material_center,
        material_left,
        material_right,
        material_bubble,
    };
    const material_buffer = metal.Buffer.initWithBuffer(renderer, &materials) orelse
        return error.MetalBufferFailed;
    defer material_buffer.deinit();

    const spheres = [_]Sphere{
        .{ .center = .{ 0, -100.5, -1 }, .radius = 100, .material_index = 0 },
        .{ .center = .{ 0.0, 0.0, -1.2 }, .radius = 0.5, .material_index = 1 },
        .{ .center = .{ -1.0, 0.0, -1.0 }, .radius = 0.5, .material_index = 2 },
        .{ .center = .{ -1.0, 0.0, -1.0 }, .radius = 0.4, .material_index = 4 },
        .{ .center = .{ 1.0, 0.0, -1.0 }, .radius = 0.5, .material_index = 3 },
    };
    const sphere_buffer = metal.Buffer.initWithBuffer(renderer, &spheres) orelse
        return error.MetalBufferFailed;
    defer sphere_buffer.deinit();

    while (runtime.isRunning()) {
        const frame_ns = zen.Runtime.ticksNS();
        const delta_time =
            @as(f32, @floatFromInt(frame_ns - last_frame_ns)) /
            @as(f32, @floatFromInt(std.time.ns_per_s));
        last_frame_ns = frame_ns;

        // EVENT LOOP
        while (runtime.pollEvent()) |event| {
            switch (event) {
                .key_down => |key| {
                    if (key.key == .f) {
                        if (!camera_control.rotate_camera) {
                            camera_control.rotate_camera = true;
                            try runtime.setRelativeMouseMode(true);
                        }
                    }
                    camera_control.setMovementKey(key.key, true);
                },
                .key_up => |key| {
                    if (key.key == .f) {
                        if (camera_control.rotate_camera) {
                            camera_control.rotate_camera = false;
                            try runtime.setRelativeMouseMode(false);
                        }
                    }
                    camera_control.setMovementKey(key.key, false);
                },
                .mouse_motion => |mouse| {
                    if (camera_control.rotate_camera) {
                        camera.rotate(
                            -mouse.dx * mouse_sensitivity,
                            -mouse.dy * mouse_sensitivity,
                        );
                    }
                },
                else => {},
            }
        }

        camera_control.update(&camera, delta_time, move_speed);

        const runtime_size = runtime.size() orelse {
            continue;
        };

        const new_width = runtime_size.width;
        const new_height = runtime_size.height;

        // render logic

        // resize texture
        if (new_width != image_width or new_height != image_height) {
            renderer.resize(new_width, new_height);
            image.deinit();

            image_width = new_width;
            image_height = new_height;

            const resized_image_desc = metal.TextureDesc{
                .width = image_width,
                .height = image_height,
                .format = .rgba8_unorm,
                .usage = @as(u32, @bitCast(metal.TextureUsage{
                    .shader_read = true,
                    .shader_write = true,
                })),
            };

            image = metal.Texture.init(renderer, &resized_image_desc) orelse
                return error.MetalTextureFailed;
        }

        const camera_input = camera.buildShaderInput(image_width, image_height);

        // render
        const frame = metal.Frame.init(renderer) orelse continue;
        const compute_pass = metal.ComputePass.init(frame) orelse {
            frame.present();
            return error.MetalComputePassFailed;
        };

        const params = RayTraceInput{
            .image_width = image_width,
            .image_height = image_height,
            .camera_center = camera_input.camera_center,
            .pixel_delta_u = camera_input.pixel_delta_u,
            .pixel_delta_v = camera_input.pixel_delta_v,
            .viewport_upper_left = camera_input.viewport_upper_left,
            .sphere_count = spheres.len,
            .material_count = materials.len,
        };
        param_buffer.write(&params);

        compute_pass.setPipeline(compute_pipeline);
        compute_pass.setTexture(0, image);
        compute_pass.setBuffer(0, param_buffer);
        compute_pass.setBuffer(1, sphere_buffer);
        compute_pass.setBuffer(2, material_buffer);
        compute_pass.dispatch(image_width, image_height, 1);
        compute_pass.end();

        const render_pass = metal.RenderPass.init(
            frame,
            0.0,
            0.0,
            0.0,
            1.0,
        ) orelse {
            frame.present();
            return error.MetalRenderPassFailed;
        };

        render_pass.setPipeline(render_pipeline);
        render_pass.setFragmentTexture(0, image);
        render_pass.draw(3);
        render_pass.end();
        frame.present();
    }
}

const CameraControl = struct {
    move_forward: bool = false,
    move_backward: bool = false,
    move_left: bool = false,
    move_right: bool = false,
    move_up: bool = false,
    move_down: bool = false,
    rotate_camera: bool = false,

    fn setMovementKey(control: *CameraControl, key: zen.Runtime.Key, down: bool) void {
        switch (key) {
            .w, .up => control.move_forward = down,
            .s, .down => control.move_backward = down,
            .a, .left => control.move_left = down,
            .d, .right => control.move_right = down,
            .e, .space => control.move_up = down,
            .q => control.move_down = down,
            else => {},
        }
    }

    fn update(control: CameraControl, camera: *Camera, delta_time: f32, speed: f32) void {
        const forward = common.normalize(camera.lookat - camera.transform);
        const right = common.normalize(common.cross(forward, camera.vup));
        const up = common.normalize(camera.vup);
        var movement = Vector3{ 0.0, 0.0, 0.0 };

        if (control.move_forward) movement += forward;
        if (control.move_backward) movement -= forward;
        if (control.move_right) movement += right;
        if (control.move_left) movement -= right;
        if (control.move_up) movement += up;
        if (control.move_down) movement -= up;

        if (@reduce(.Add, movement * movement) > 0.0) {
            camera.translate(
                common.normalize(movement) *
                    @as(Vector3, @splat(speed * delta_time)),
            );
        }
    }
};
