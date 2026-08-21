const std = @import("std");
const sdl = @import("sdl");

const Runtime = @This();

pub const Size = struct {
    width: u32,
    height: u32,
};

window: *sdl.SDL_Window,
metal_view: sdl.SDL_MetalView,
running: bool,

pub fn init(width: u32, height: u32) !Runtime {
    _ = sdl.SDL_SetAppMetadata("Zen", "0.0.0", "app.yuhao.zen");

    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        std.log.err("Couldn't initialize SDL: {s}", .{sdl.SDL_GetError()});
        return error.SdlInitFailed;
    }

    const window = sdl.SDL_CreateWindow(
        "Zen",
        @intCast(width),
        @intCast(height),
        sdl.SDL_WINDOW_METAL | sdl.SDL_WINDOW_RESIZABLE,
    ) orelse {
        std.log.err("Couldn't create window: {s}", .{sdl.SDL_GetError()});
        sdl.SDL_Quit();
        return error.SdlCreateWindowFailed;
    };

    const metal_view = sdl.SDL_Metal_CreateView(window) orelse {
        std.log.err("Couldn't create Metal view: {s}", .{sdl.SDL_GetError()});
        sdl.SDL_DestroyWindow(window);
        sdl.SDL_Quit();
        return error.SdlCreateMetalViewFailed;
    };

    return .{
        .window = window,
        .metal_view = metal_view,
        .running = true,
    };
}

pub fn deinit(runtime: *Runtime) void {
    sdl.SDL_Metal_DestroyView(runtime.metal_view);
    sdl.SDL_DestroyWindow(runtime.window);
    sdl.SDL_Quit();
}

pub fn pollEvents(runtime: *Runtime) void {
    var event: sdl.SDL_Event = undefined;

    while (sdl.SDL_PollEvent(&event)) {
        switch (event.type) {
            sdl.SDL_EVENT_QUIT => runtime.running = false,
            else => {},
        }
    }
}

pub fn isRunning(runtime: *const Runtime) bool {
    return runtime.running;
}

pub fn metalLayer(runtime: *Runtime) !*anyopaque {
    return sdl.SDL_Metal_GetLayer(runtime.metal_view) orelse {
        std.log.err("Couldn't create Metal layer: {s}", .{sdl.SDL_GetError()});
        return error.SdlCreateMetalLayerFailed;
    };
}

pub fn size(runtime: *Runtime) ?Size {
    var width: c_int = 0;
    var height: c_int = 0;

    _ = sdl.SDL_GetWindowSizeInPixels(runtime.window, &width, &height);

    if (width <= 0 or height <= 0) {
        return null;
    }

    return .{
        .width = @intCast(width),
        .height = @intCast(height),
    };
}
