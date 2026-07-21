const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // --- Native build (Linux on this host; overridable with -Dtarget=...) ---
    // zig build produces zig-out/bin/hello_sdl3
    const native_exe = addExe(b, .{
        .target = target,
        .optimize = optimize,
        .name = "hello_sdl3",
    });
    b.installArtifact(native_exe);

    // --- Windows cross-compile build ---
    // Zig is a native cross-compiler and ships mingw-w64, so building a
    // Windows .exe from Linux needs no extra toolchain. This produces
    // zig-out/bin/hello_sdl3.exe. SDL3 is rebuilt from source for the
    // Windows target (Win32/WASAPI/D3D11 backends) and linked statically.
    const windows_target = b.resolveTargetQuery(.{
        .os_tag = .windows,
        .cpu_arch = .x86_64,
        .abi = .gnu, // mingw-w64 ABI
    });
    const windows_exe = addExe(b, .{
        .target = windows_target,
        .optimize = optimize,
        // Zig auto-appends ".exe" for Windows targets, so the base
        // name here is given without an extension. The installed file
        // ends up at zig-out/bin/hello_sdl3.exe.
        .name = "hello_sdl3",
        // Use the GUI subsystem so Windows doesn't pop up a background
        // console window next to the SDL window. Trade-off: stdout/stderr
        // from std.debug.print no longer appear anywhere on Windows.
        .subsystem = .windows,
    });
    b.installArtifact(windows_exe);

    // --- "zig build run" step ---
    // Only runs the native build — you can't execute a Windows .exe
    // binary directly on Linux.
    const run_cmd = b.addRunArtifact(native_exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the SDL3 hello world app");
    run_step.dependOn(&run_cmd.step);
}

// --- Helper: build the SDL3 hello-world exe for one target ---
// Pulled into a function so the native and Windows builds share the
// exact same wiring. Only the target (and output name) differ.
const ExeOpts = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    name: []const u8,
    // Optional Windows subsystem. Set to .windows for GUI apps to avoid
    // the background console window. null = use Zig's default (console
    // on Windows; ignored on other OSes).
    subsystem: ?std.zig.Subsystem = null,
};

fn addExe(b: *std.Build, opts: ExeOpts) *std.Build.Step.Compile {
    const app_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = opts.target,
        .optimize = opts.optimize,
    });

    const exe = b.addExecutable(.{
        .name = opts.name,
        .root_module = app_mod,
    });
    if (opts.subsystem) |subsystem| {
        exe.subsystem = subsystem;
    }

    // "sdl" matches the key in build.zig.zon's .dependencies section.
    // Forwarding target+optimize makes SDL3 build for the same platform
    // as our app (so the Windows build gets SDL3's Win32 backend, etc.).
    const sdl_dep = b.dependency("sdl", .{
        .target = opts.target,
        .optimize = opts.optimize,
    });

    // "SDL3" is the artifact name exposed by castholm/SDL's build.zig.
    // It builds SDL3 from source as a static library for the given target.
    const sdl_lib = sdl_dep.artifact("SDL3");

    // linkLibrary() makes SDL3's symbols available to our Zig code AND
    // propagates SDL3's public include path so @cImport works.
    app_mod.linkLibrary(sdl_lib);

    return exe;
}
