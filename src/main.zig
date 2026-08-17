const std = @import("std");
const sdl = @import("sdl");

pub fn main(init: std.process.Init) !void {
    _ = init;

    _ = sdl.SDL_SetAppMetadata("Zen", "0.0.0", "app.yuhao.zen");

    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        std.log.err("Couldn't initialize SDL: {s}", .{sdl.SDL_GetError()});
        return error.SdlInitFailed;
    }
    defer sdl.SDL_Quit();

    var window: ?*sdl.SDL_Window = null;
    var renderer: ?*sdl.SDL_Renderer = null;

    if (!sdl.SDL_CreateWindowAndRenderer("Zen", 1280, 720, sdl.SDL_WINDOW_RESIZABLE, &window, &renderer)) {
        std.log.err("Couldn't crate window/renderer: {s}", .{sdl.SDL_GetError()});
        return error.SdlCreateWindowAndRendererFailed;
    }

    defer sdl.SDL_DestroyRenderer(renderer.?);
    defer sdl.SDL_DestroyWindow(window.?);

    _ = sdl.SDL_SetRenderLogicalPresentation(renderer, 1280, 720, sdl.SDL_LOGICAL_PRESENTATION_LETTERBOX);

    var running = true;

    while (running) {
        var event: sdl.SDL_Event = undefined;

        while (sdl.SDL_PollEvent(&event)) {
            switch (event.type) {
                sdl.SDL_EVENT_QUIT => running = false,
                else => {},
            }
        }
    }
}
