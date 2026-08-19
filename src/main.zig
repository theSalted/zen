const std = @import("std");
const sdl = @import("sdl");
const metal = @import("metal.zig");

const Vector3 = @Vector(3, f32);

pub const RayTraceInput = extern struct {
    image_width: u32,
    image_height: u32,

    camera_center: Vector3,
    pixel_delta_u: Vector3,
    pixel_delta_v: Vector3,
    viewport_upper_left: Vector3,
};

pub fn main(init: std.process.Init) !void {
    _ = init;

    _ = sdl.SDL_SetAppMetadata("Zen", "0.0.0", "app.yuhao.zen");

    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        std.log.err("Couldn't initialize SDL: {s}", .{sdl.SDL_GetError()});
        return error.SdlInitFailed;
    }
    defer sdl.SDL_Quit();

    const width = 1280;
    const height = 720;

    const window = sdl.SDL_CreateWindow("Zen", width, height, sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_METAL);

    if (window == null) {
        std.log.err("Couldn't crate window: {s}", .{sdl.SDL_GetError()});
        return error.SdlCreateWindowFailed;
    }

    defer sdl.SDL_DestroyWindow(window.?);

    const metal_view = sdl.SDL_Metal_CreateView(window);
    defer sdl.SDL_Metal_DestroyView(metal_view);

    const layer = sdl.SDL_Metal_GetLayer(metal_view);

    if (layer == null) {
        std.log.err("Couldn't create metal render layer: {s}", .{sdl.SDL_GetError()});
        return error.SdlCreateMetalLayerFailed;
    }

    const shader = @embedFile("shaders/gradient.metal");
    const shader_sources = [_]metal.ShaderSource{
        .{
            .source = shader.ptr,
            .source_len = shader.len,
        },
    };

    const renderer = metal.Renderer.init(layer.?, width, height) orelse
        return error.MetalCreateFailed;
    defer renderer.deinit();

    const library = metal.ShaderLibrary.init(renderer, &shader_sources) orelse
        return error.MetalShaderLibraryFailed;
    defer library.deinit();

    const render_pipeline = metal.RenderPipeline.init(renderer, library, "vertex_main", "fragment_main") orelse
        return error.MetalRenderPipelineFailed;
    defer render_pipeline.deinit();

    const compute_pipeline = metal.ComputePipeline.init(renderer, library, "gradient_kernel") orelse
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

    const image = metal.Texture.init(renderer, &image_desc) orelse {
        return error.MetalTextureFailed;
    };
    defer image.deinit();

    var running = true;

    while (running) {
        var event: sdl.SDL_Event = undefined;

        var w: c_int = 0;
        var h: c_int = 0;

        _ = sdl.SDL_GetWindowSizeInPixels(window, &w, &h);

        const pixel_width: u32 = @intCast(w);
        const pixel_height: u32 = @intCast(h);

        while (sdl.SDL_PollEvent(&event)) {
            switch (event.type) {
                sdl.SDL_EVENT_QUIT => running = false,
                else => {},
            }
        }

        // logic
        const aspect_ratio = pixel_width / pixel_height;
        const focal_length: f32 = 1.0;
        const viewport_height: f32 = 2.0;
        const viewport_width = viewport_height * @as(f32, @floatFromInt(aspect_ratio));
        const camera_center: Vector3 = .{ 0, 0, 0 };

        const viewport_u: Vector3 = .{ viewport_width, 0, 0 };
        const viewport_v: Vector3 = .{ 0, -viewport_height, 0 };

        const pixel_delta_u = viewport_u / @as(Vector3, @splat(@as(f32, @floatFromInt(pixel_width))));
        const pixel_delta_v = viewport_v / @as(Vector3, @splat(@as(f32, @floatFromInt(pixel_height))));

        const viewport_upper_left = camera_center - Vector3{ 0, 0, focal_length } - viewport_u / @as(Vector3, @splat(2.0)) - viewport_v / @as(Vector3, @splat(2.0));

        // render
        const frame = metal.Frame.init(renderer) orelse continue;
        const compute_pass = metal.ComputePass.init(frame) orelse {
            frame.present();
            return error.MetalComputePassFailed;
        };

        const params = RayTraceInput{
            .image_width = pixel_width,
            .image_height = pixel_height,
            .camera_center = .{ 0, 0, 0 },
            .pixel_delta_u = pixel_delta_u,
            .pixel_delta_v = pixel_delta_v,
            .viewport_upper_left = viewport_upper_left,
        };
        const buffer = metal.Buffer.init(renderer, &params) orelse
            return error.MetalBufferFailed;

        compute_pass.setPipeline(compute_pipeline);
        compute_pass.setTexture(0, image);
        compute_pass.setBuffer(0, buffer);
        compute_pass.dispatch(width, height, 1);
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
