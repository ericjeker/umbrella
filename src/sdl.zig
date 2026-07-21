// Single shared SDL3 C interop module.
//
// @cImport is done ONCE here and re-exported; every other file imports
// this module instead of re-running @cImport. This matters because each
// @cImport produces a fresh namespace of generated types — two separate
// @cImport blocks would yield two distinct `SDL_Renderer` opaque types
// that share a name but are not the same type (Zig is nominal, not
// structural), and passing one into a function expecting the other is
// a compile error even though the names print identically.
pub const sdl = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("SDL3/SDL_main.h");
});
