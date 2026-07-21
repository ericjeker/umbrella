const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // --- Native build (Linux on this host; overridable with -Dtarget=...) ---
    // zig build produces zig-out/bin/umbrella
    const native_exe = addExe(b, .{
        .target = target,
        .optimize = optimize,
        .name = "umbrella",
    });
    b.installArtifact(native_exe);

    // --- Windows cross-compile build ---
    // Zig is a native cross-compiler and ships mingw-w64, so building a
    // Windows .exe from Linux needs no extra toolchain. This produces
    // zig-out/bin/umbrella.exe. SDL3 is rebuilt from source for the
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
        // ends up at zig-out/bin/umbrella.exe.
        .name = "umbrella",
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

    const run_step = b.step("run", "Run the SDL3 Umbrella app");
    run_step.dependOn(&run_cmd.step);

    // --- "zig build test" step ---
    // Each call to addTest wires one *_test.zig file into the test step.
    // Adding a new test file is one more line here; the helper handles the
    // shared "sdl" import and the run-artifact wiring. All test runs are
    // dependents of the single `test` step, so `zig build test` runs them all.
    const test_step = b.step("test", "Run unit tests");
    addTest(b, test_step, target, optimize, "src/entities/triangle_test.zig");
}

// --- Helper: build the SDL3 umbrella exe for one target ---
// Pulled into a function so the native and Windows builds share the
// exact same wiring. Only the target (and output name) differ.
const ExeOpts = struct {
    root_source_file: []const u8 = "src/main.zig",
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
        .root_source_file = b.path(opts.root_source_file),
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

    // Expose SDL3 to this module under the import name "sdl". Every .zig
    // file in this module tree (main.zig AND entities/*.zig reached via
    // relative @import) can then `@import("sdl")` and get the SAME shared
    // @cImport namespace — no fragile "../sdl.zig" relative paths, and no
    // risk of two distinct SDL_Renderer types from two @cImport blocks.
    app_mod.addImport("sdl", addSdlModule(b, opts.target, opts.optimize));

    return exe;
}

// --- Helper: wire one *_test.zig file into the `test` step ---
// A test artifact is structurally like an exe (root module + linked libs)
// but `zig build test` runs it instead of installing it. The test module
// gets the same shared "sdl" import as the exes, because modules under test
// (e.g. entities/triangle.zig) import SDL for drawing — even when the test
// itself only exercises pure math. Each call registers one test run as a
// dependent of `test_step`, so `zig build test` runs every registered file.
fn addTest(
    b: *std.Build,
    test_step: *std.Build.Step,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    root_source_file: []const u8,
) void {
    const test_mod = b.createModule(.{
        .root_source_file = b.path(root_source_file),
        .target = target,
        .optimize = optimize,
    });
    test_mod.addImport("sdl", addSdlModule(b, target, optimize));
    const test_exe = b.addTest(.{ .root_module = test_mod });
    const run_tests = b.addRunArtifact(test_exe);
    test_step.dependOn(&run_tests.step);
}

// --- Helper: the shared SDL3 C-interop module, importable as "sdl" ---
// One @cImport namespace per target. Per-target because SDL3 is built
// from source separately for native vs Windows (different backends), and
// the @cImport-generated types are tied to that build. Callers addImport
// this into their module so any file at any depth can `@import("sdl")`.
fn addSdlModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    const sdl_mod = b.createModule(.{
        .root_source_file = b.path("src/sdl.zig"),
        .target = target,
        .optimize = optimize,
    });
    // linkLibrary on sdl_mod (not on app_mod) — SDL3's symbols and public
    // include path become available to the @cImport inside sdl.zig, and
    // propagate transitively to any module that addImports sdl_mod.
    sdl_mod.linkLibrary(b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
    }).artifact("SDL3"));
    return sdl_mod;
}
