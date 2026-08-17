const std = @import("std");
const sdl = @import("sdl");

pub fn main(init: std.process.Init) !void {
    _ = init;

    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        return error.SdlInitFailed;
    }
    defer sdl.SDL_Quit();
}
