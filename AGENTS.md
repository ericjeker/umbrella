# Zig + SDL3 project context

This is a Zig project that builds a minimal SDL3 hello-world application
(window + event loop) for both Linux and Windows from a single `zig build`.

## Toolchain

- **Zig 0.16.0** must be installed locally and on `PATH` as `zig`.
  Do NOT reinstall Zig — it is already present and working.

- No system SDL installation is required. SDL3 is built from source as a Zig
  package (see "Dependency" below). Do NOT `apt install libsdl3-dev` — it is
  unnecessary and would shadow the package-built SDL3.

- Zig is a native cross-compiler and ships mingw-w64, so building a Windows
  `.exe` from Linux needs no extra toolchain (no MinGW, no Visual Studio).

## Project layout

```
<projectRoot>/
├── AGENTS.md        ← this file
├── build.zig        ← build script: defines Linux + Windows exes, links SDL3
├── build.zig.zon    ← manifest: pins the SDL3 package (URL + content hash)
└── src/
    └── main.zig     ← the SDL3 hello-world app (uses SDL3's C API via @cImport)
```

Generated / disposable (do NOT commit):
- `.zig-cache/`  — build cache
- `zig-out/`     — build output (`bin/hello_sdl3`, `bin/hello_sdl3.exe`, `*.pdb`)
- `zig-pkg/`     — fetched dependency sources (restored from `build.zig.zon` on demand)

## Dependency

SDL3 is provided by the `castholm/SDL` package — a Zig build-system port of
SDL3 that compiles the full SDL3 C library from source as a static library.

- Pinned in `build.zig.zon` under `.dependencies.sdl`:
  - URL: `git+https://github.com/castholm/SDL.git#1b67d371a531ecb0499d4b80a865631c299f472a`
  - Hash: `sdl-0.5.2+3.4.12-SDL--qPKpwHc40bqAlYs7W9pXJVyLwsGDNa4shNXbOZr`
  - Resolves to package version 0.5.2+3.4.12 (SDL 3.4.12).
- Added originally with: `zig fetch --save git+https://github.com/castholm/SDL.git`
  (Do not re-run unless updating — see "Updating / removing" below.)

The manifest is the lock: the URL pins a specific git commit and the hash pins
exact content. There is no separate lockfile. `zig build` reproducibly fetches
the same SDL3 bytes into `zig-pkg/`.

## How the build is wired

`build.zig` produces **two executables from a single `zig build`**:

1. **Native Linux build** — uses `b.standardTargetOptions(.{})`, so it honors
   `-Dtarget=` overrides but defaults to the host. Installs to
   `zig-out/bin/hello_sdl3`.
2. **Windows cross-compile build** — hardcoded target
   `x86_64-windows-gnu` (mingw-w64 ABI). Installs to `zig-out/bin/hello_sdl3.exe`.
   Uses the GUI subsystem (`.subsystem = .windows`) so no background CMD window
   appears on Windows; trade-off is that `std.debug.print` output is not visible
   on Windows.

Both builds share a single `addExe` helper in `build.zig`. Only the `target`,
output `name`, and optional `subsystem` differ. SDL3 is rebuilt from source
separately for each target (X11/Wayland backends for Linux, Win32/D3D11/WASAPI
backends for Windows) and statically linked into the executable.

`src/main.zig` accesses SDL3 through direct C interop:
```zig
const sdl = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("SDL3/SDL_main.h");
});
```
`linkLibrary(sdl_dep.artifact("SDL3"))` in `build.zig` propagates SDL3's public
include path so `@cImport` can find `SDL3/SDL.h`. No Zig SDL wrapper package is
involved.

## Build / run commands

```bash
zig build                     # build BOTH → zig-out/bin/hello_sdl3 + hello_sdl3.exe
zig build --summary all       # same, prints the per-target build tree
zig build run                 # builds both, runs ONLY the native Linux exe
                              # (a Windows .exe cannot run directly on Linux)
zig build -Doptimize=ReleaseFast   # release build (much smaller binaries)
zig build test                # compile + run unit tests (src/entities/*_test.zig)
                              # wired via a `test` step in build.zig
zig build test --summary all  # same, prints pass/fail counts per test
```

## Running on this WSL host

SDL3 on Linux needs a display. Under WSL, `zig build run` will fail with
`SDL_Init failed: No available video device` unless the Wayland socket path is
fixed — WSLg puts it at `/mnt/wslg/runtime-dir/wayland-0`, not under the
default `$XDG_RUNTIME_DIR`. Run with:

```bash
XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir WAYLAND_DISPLAY=wayland-0 zig build run
```

Or persist the WSLg runtime dir in `~/.bashrc`:
```bash
export XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir
export WAYLAND_DISPLAY=wayland-0
```

To verify the app without any display (smoke test, runs the full event loop
using SDL3's dummy video driver):
```bash
SDL_VIDEODRIVER=dummy ./zig-out/bin/hello_sdl3
```

To test the Windows `.exe` from WSL, invoke it directly — WSL hands it to
Windows to execute as a native Windows process on the Windows desktop:
```bash
./zig-out/bin/hello_sdl3.exe
```

## Updating / removing SDL3

- **Update to a newer SDL3**: re-run
  `zig fetch --save git+https://github.com/castholm/SDL.git` — it resolves the
  latest commit and rewrites the `url`/`hash` in `build.zig.zon`. Review the
  diff before committing.
- **Remove**: delete the `.sdl = .{ ... }` block from `build.zig.zon`, remove
  the `b.dependency("sdl", ...)` / `linkLibrary` lines from `build.zig` (or the
  `addExe` helper), and remove the `@cImport` block from `src/main.zig`. Then
  `rm -rf zig-pkg .zig-cache` to drop cached sources.

## Known gotchas

- **Zig auto-appends `.exe` for Windows targets.** In `build.zig`, the Windows
  executable's `.name` is `"hello_sdl3"` (no extension); the installed file
  becomes `zig-out/bin/hello_sdl3.exe`. Passing `.name = "hello_sdl3.exe"`
  would produce `hello_sdl3.exe.exe`.
- **SDL3 uses dynamic loading for X11/Wayland client libs on Linux.** The
  Linux binary is statically linked against SDL3 itself, but SDL3 dlopens
  `libX11.so.6`, `libwayland-client.so.0`, etc. at runtime. Those system libs
  must be present on the target Linux machine (they are on this WSL host).
- **Debug builds are large.** ~78 MB (Linux) and ~26 MB (Windows) because they
  include full debug info and are unstripped. Use `-Doptimize=ReleaseFast` for
  release-size binaries.
- **GUI subsystem suppresses console output on Windows.** Because
  `.subsystem = .windows`, `std.debug.print` output is not visible when running
  `hello_sdl3.exe` on Windows. The app still runs; only the SDL window appears.
