const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // zig build vendor
    const vendor_config = b.addSystemCommand(&.{
        "cmake",
        "-S",
        "vendor",
        "-B",
        "build/vendor",
        "-DCMAKE_BUILD_TYPE=Release",
    });

    const vendor_build = b.addSystemCommand(&.{
        "cmake",
        "--build",
        "build/vendor",
        "--config",
        "Release",
    });

    vendor_build.step.dependOn(&vendor_config.step);

    const vendor_step = b.step("vendor", "Build vendor libraries");
    vendor_step.dependOn(&vendor_build.step);

    const sdl_translate = b.addTranslateC(.{
        .root_source_file = b.path("src/sdl.h"),
        .target = target,
        .optimize = optimize,
    });
    sdl_translate.addIncludePath(b.path("vendor/SDL/include"));

    const sdl_mod = sdl_translate.createModule();

    // Public Zen module.
    const mod = b.addModule("zen", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    mod.link_libc = true;
    mod.addIncludePath(b.path("vendor/SDL/include"));
    mod.addLibraryPath(b.path("build/vendor/Release"));
    mod.linkSystemLibrary("SDL3", .{});
    mod.addImport("sdl", sdl_mod);

    // Application executable.
    const exe = b.addExecutable(.{
        .name = "zen",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zen", .module = mod },
                .{ .name = "sdl", .module = sdl_mod },
            },
        }),
    });

    exe.root_module.link_libc = true;
    exe.root_module.addIncludePath(b.path("vendor/SDL/include"));
    exe.root_module.addLibraryPath(b.path("build/vendor/Release"));
    exe.root_module.linkSystemLibrary("SDL3", .{});

    // Configure runtime lookup and install the appropriate shared library.
    switch (target.result.os.tag) {
        .macos => {
            exe.root_module.addRPath(.{
                .cwd_relative = "@loader_path",
            });

            const install_sdl = b.addInstallFileWithDir(
                b.path("build/vendor/Release/libSDL3.0.dylib"),
                .bin,
                "libSDL3.0.dylib",
            );

            b.getInstallStep().dependOn(&install_sdl.step);
        },

        .linux => {
            exe.root_module.addRPath(.{
                .cwd_relative = "$ORIGIN",
            });

            const install_sdl = b.addInstallFileWithDir(
                b.path("build/vendor/Release/libSDL3.so.0"),
                .bin,
                "libSDL3.so.0",
            );

            b.getInstallStep().dependOn(&install_sdl.step);
        },

        .windows => {
            const install_sdl = b.addInstallFileWithDir(
                b.path("build/vendor/Release/SDL3.dll"),
                .bin,
                "SDL3.dll",
            );

            b.getInstallStep().dependOn(&install_sdl.step);
        },

        else => @panic("Unsupported target platform"),
    }

    b.installArtifact(exe);

    // zig build run
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);

    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    // addRunArtifact runs from Zig's build cache, so expose SDL's build folder
    // to the runtime loader.
    switch (target.result.os.tag) {
        .macos => {
            run_cmd.setEnvironmentVariable(
                "DYLD_LIBRARY_PATH",
                "build/vendor/Release",
            );
        },
        .linux => {
            run_cmd.setEnvironmentVariable(
                "LD_LIBRARY_PATH",
                "build/vendor/Release",
            );
        },
        .windows => {
            run_cmd.setEnvironmentVariable(
                "PATH",
                "build/vendor/Release",
            );
        },
        else => {},
    }

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // zig build test
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
