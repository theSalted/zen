const std = @import("std");
const math = std.math;
const zen = @import("zen");
const metal = zen.graphics.metal;
const common = @import("common.zig");

const Vector3 = common.Vector3;
const Material = common.Material;
const Sphere = common.Sphere;

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
    const vfov: f32 = 90;

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

    var image_width: u32 = width;
    var image_height: u32 = height;

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
        runtime.pollEvents();

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

        const aspect_ratio =
            @as(f32, @floatFromInt(image_width)) /
            @as(f32, @floatFromInt(image_height));
        const focal_length: f32 = 1.0;
        const theta = common.degrees_to_radians(vfov);
        const ih = math.tan(theta / 2);
        const viewport_height: f32 = 2.0 * ih * focal_length;
        const viewport_width = viewport_height * aspect_ratio;
        const camera_center: Vector3 = .{ 0, 0, 0 };

        const viewport_u: Vector3 = .{ viewport_width, 0, 0 };
        const viewport_v: Vector3 = .{ 0, -viewport_height, 0 };

        const pixel_delta_u = viewport_u / @as(Vector3, @splat(@as(f32, @floatFromInt(image_width))));
        const pixel_delta_v = viewport_v / @as(Vector3, @splat(@as(f32, @floatFromInt(image_height))));

        const viewport_upper_left = camera_center - Vector3{ 0, 0, focal_length } - viewport_u / @as(Vector3, @splat(2.0)) - viewport_v / @as(Vector3, @splat(2.0));

        // render
        const frame = metal.Frame.init(renderer) orelse continue;
        const compute_pass = metal.ComputePass.init(frame) orelse {
            frame.present();
            return error.MetalComputePassFailed;
        };

        const params = RayTraceInput{
            .image_width = image_width,
            .image_height = image_height,
            .camera_center = .{ 0, 0, 0 },
            .pixel_delta_u = pixel_delta_u,
            .pixel_delta_v = pixel_delta_v,
            .viewport_upper_left = viewport_upper_left,
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
