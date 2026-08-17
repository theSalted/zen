const std = @import("std");
const sdl = @import("sdl");
const metal = @import("metal.zig");

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
    const shader_sources = [_]metal.ShaderSource{
        .{
            .source = shader.ptr,
            .source_len = shader.len,
        },
    };

    const renderer = metal.create(layer.?, width, height) orelse {
        return error.MetalCreateFailed;
    };
    defer metal.destroy(renderer);

    const library = metal.createShaderLibrary(renderer, &shader_sources) orelse {
        return error.MetalShaderLibraryFailed;
    };
    defer metal.destroyShaderLibrary(library);

    const pipeline = metal.createRenderPipeline(renderer, library, "vertex_main", "fragment_main") orelse {
        return error.MetalPipelineFailed;
    };
    defer metal.destroyRenderPipeline(pipeline);

    var running = true;

    while (running) {
        var event: sdl.SDL_Event = undefined;

        while (sdl.SDL_PollEvent(&event)) {
            switch (event.type) {
                sdl.SDL_EVENT_QUIT => running = false,
                else => {},
            }
        }

        const frame = metal.beginFrame(renderer) orelse continue;
        const pass = metal.beginRenderPass(frame, 0.02, 0.02, 0.025, 1.0) orelse {
            metal.present(frame);
            return error.MetalRenderPassFailed;
        };

        metal.renderPassSetPipeline(pass, pipeline);
        metal.renderPassDraw(pass, 3);
        metal.endRenderPass(pass);
        metal.present(frame);
    }
}
