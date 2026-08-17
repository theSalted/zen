const std = @import("std");
const sdl = @import("sdl");

const MetalRenderer = opaque {};
const MetalRenderPipeline = opaque {};

extern fn metal_create(raw_layer: *anyopaque, width: u32, height: u32) ?*MetalRenderer;
extern fn metal_render(renderer: *MetalRenderer, pipeline: *MetalRenderPipeline) void;
extern fn metal_resize(renderer: *MetalRenderer, width: u32, height: u32) void;
extern fn metal_destroy(renderer: *MetalRenderer) void;

extern fn metal_create_render_pipeline(
    renderer: *MetalRenderer,
    shader_source: [*]const u8,
    shader_source_len: usize,
    vertex_name: [*:0]const u8,
    fragment_name: [*:0]const u8,
) ?*MetalRenderPipeline;
extern fn metal_destroy_render_pipeline(pipeline: *MetalRenderPipeline) void;

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

    const shader = @embedFile("shaders/fullscreen_triangle.metal");

    const metal = metal_create(layer.?, width, height) orelse {
        return error.MetalCreateFailed;
    };
    defer metal_destroy(metal);

    const pipeline = metal_create_render_pipeline(metal, shader.ptr, shader.len, "vertex_main", "fragment_main") orelse {
        return error.MetalPipelineFailed;
    };
    defer metal_destroy_render_pipeline(pipeline);

    var running = true;

    while (running) {
        var event: sdl.SDL_Event = undefined;

        while (sdl.SDL_PollEvent(&event)) {
            switch (event.type) {
                sdl.SDL_EVENT_QUIT => running = false,
                else => {},
            }
        }

        metal_render(metal, pipeline);
    }
}
