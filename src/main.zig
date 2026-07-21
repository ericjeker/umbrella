const std = @import("std");

// SDL3 C interop is exposed by build.zig as a named module "sdl" (root:
// src/sdl.zig). Importing it by name — not via a relative path — means
// every file in the module tree sees the SAME generated SDL types.
const sdl = @import("sdl").sdl;

const Triangle = @import("entities/triangle.zig").Triangle;

pub fn main() !void {
    // Required when SDL_MAIN_HANDLED is set — tells SDL the main
    // function is ready before we call SDL_Init().
    sdl.SDL_SetMainReady();

    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        std.debug.print("SDL_Init failed: {s}\n", .{sdl.SDL_GetError()});
        return error.SdlInitFailed;
    }
    defer sdl.SDL_Quit();

    const window = sdl.SDL_CreateWindow(
        "Hello SDL3 from Zig!",
        800,
        600,
        sdl.SDL_WINDOW_RESIZABLE,
    );
    if (window == null) {
        std.debug.print("SDL_CreateWindow failed: {s}\n", .{sdl.SDL_GetError()});
        return error.SdlCreateWindowFailed;
    }
    defer sdl.SDL_DestroyWindow(window);

    const renderer = sdl.SDL_CreateRenderer(window, null);
    if (renderer == null) {
        std.debug.print("SDL_CreateRenderer failed: {s}\n", .{sdl.SDL_GetError()});
        return error.SdlCreateRendererFailed;
    }
    defer sdl.SDL_DestroyRenderer(renderer);

    std.debug.print("SDL3 running! Press Q or close the window to quit.\n", .{});

    var tri = Triangle.init(400.0, 300.0, 120.0, 0);

    var quit = false;
    while (!quit) {
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event)) {
            switch (event.type) {
                sdl.SDL_EVENT_QUIT => quit = true,
                sdl.SDL_EVENT_KEY_DOWN => {
                    if (event.key.key == sdl.SDLK_Q or event.key.key == sdl.SDLK_ESCAPE) {
                        quit = true;
                    }
                },
                else => {},
            }
        }

        tri.rotate(0.1);

        // Clear with a dark blue background each frame
        _ = sdl.SDL_SetRenderDrawColor(renderer, 30, 40, 80, 255);
        _ = sdl.SDL_RenderClear(renderer);
        tri.draw(renderer);
        _ = sdl.SDL_RenderPresent(renderer);
    }

    std.debug.print("Goodbye!\n", .{});
}
