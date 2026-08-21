const std = @import("std");
const sdl = @import("sdl");

const Runtime = @This();

pub const Size = struct {
    width: u32,
    height: u32,
};

pub const Event = union(enum) {
    quit,
    key_down: KeyEvent,
    key_up: KeyEvent,
    mouse_motion: MouseMotionEvent,
    mouse_button_down: MouseButtonEvent,
    mouse_button_up: MouseButtonEvent,
    mouse_wheel: MouseWheelEvent,
};

pub const KeyEvent = struct {
    key: Key,
    keycode: u32,
    scancode: u32,
    modifiers: u16,
    repeat: bool,
};

pub const Key = enum {
    unknown,
    w,
    a,
    s,
    d,
    q,
    e,
    up,
    down,
    left,
    right,
    escape,
    space,
    left_shift,
    right_shift,
};

pub const MouseMotionEvent = struct {
    x: f32,
    y: f32,
    dx: f32,
    dy: f32,
    buttons: u32,
};

pub const MouseButtonEvent = struct {
    button: MouseButton,
    raw_button: u8,
    clicks: u8,
    x: f32,
    y: f32,
};

pub const MouseButton = enum {
    unknown,
    left,
    middle,
    right,
    x1,
    x2,
};

pub const MouseWheelEvent = struct {
    x: f32,
    y: f32,
    mouse_x: f32,
    mouse_y: f32,
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

pub fn pollEvent(runtime: *Runtime) ?Event {
    var event: sdl.SDL_Event = undefined;

    if (!sdl.SDL_PollEvent(&event)) {
        return null;
    }

    switch (event.type) {
        sdl.SDL_EVENT_QUIT => {
            runtime.running = false;
            return .quit;
        },

        sdl.SDL_EVENT_KEY_DOWN => return .{ .key_down = keyEvent(event.key) },
        sdl.SDL_EVENT_KEY_UP => return .{ .key_up = keyEvent(event.key) },

        sdl.SDL_EVENT_MOUSE_MOTION => return .{
            .mouse_motion = .{
                .x = event.motion.x,
                .y = event.motion.y,
                .dx = event.motion.xrel,
                .dy = event.motion.yrel,
                .buttons = event.motion.state,
            },
        },

        sdl.SDL_EVENT_MOUSE_BUTTON_DOWN => return .{
            .mouse_button_down = mouseButtonEvent(event.button),
        },

        sdl.SDL_EVENT_MOUSE_BUTTON_UP => return .{
            .mouse_button_up = mouseButtonEvent(event.button),
        },

        sdl.SDL_EVENT_MOUSE_WHEEL => return .{
            .mouse_wheel = .{
                .x = event.wheel.x,
                .y = event.wheel.y,
                .mouse_x = event.wheel.mouse_x,
                .mouse_y = event.wheel.mouse_y,
            },
        },

        else => return pollEvent(runtime),
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

fn keyEvent(event: sdl.SDL_KeyboardEvent) KeyEvent {
    return .{
        .key = keyFromScancode(event.scancode),
        .keycode = event.key,
        .scancode = @intCast(event.scancode),
        .modifiers = event.mod,
        .repeat = event.repeat,
    };
}

fn mouseButtonEvent(event: sdl.SDL_MouseButtonEvent) MouseButtonEvent {
    return .{
        .button = mouseButtonFromSdl(event.button),
        .raw_button = event.button,
        .clicks = event.clicks,
        .x = event.x,
        .y = event.y,
    };
}

fn keyFromScancode(scancode: sdl.SDL_Scancode) Key {
    return switch (scancode) {
        sdl.SDL_SCANCODE_W => .w,
        sdl.SDL_SCANCODE_A => .a,
        sdl.SDL_SCANCODE_S => .s,
        sdl.SDL_SCANCODE_D => .d,
        sdl.SDL_SCANCODE_Q => .q,
        sdl.SDL_SCANCODE_E => .e,
        sdl.SDL_SCANCODE_UP => .up,
        sdl.SDL_SCANCODE_DOWN => .down,
        sdl.SDL_SCANCODE_LEFT => .left,
        sdl.SDL_SCANCODE_RIGHT => .right,
        sdl.SDL_SCANCODE_ESCAPE => .escape,
        sdl.SDL_SCANCODE_SPACE => .space,
        sdl.SDL_SCANCODE_LSHIFT => .left_shift,
        sdl.SDL_SCANCODE_RSHIFT => .right_shift,
        else => .unknown,
    };
}

fn mouseButtonFromSdl(button: u8) MouseButton {
    return switch (button) {
        sdl.SDL_BUTTON_LEFT => .left,
        sdl.SDL_BUTTON_MIDDLE => .middle,
        sdl.SDL_BUTTON_RIGHT => .right,
        sdl.SDL_BUTTON_X1 => .x1,
        sdl.SDL_BUTTON_X2 => .x2,
        else => .unknown,
    };
}
