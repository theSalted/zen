const std = @import("std");

const app_name = "zen";

const root_source = "src/main.zig";
const module_source = "src/root.zig";
const metal_source = "src/graphics/metal.m";
const sdl_header = "src/sdl.h";

const vendor_source_dir = "vendor";
const vendor_build_dir = "build/vendor";
const vendor_build_type = "Release";
const vendor_release_dir = vendor_build_dir ++ "/" ++ vendor_build_type;

const sdl_include_dir = "vendor/SDL/include";
const sdl_library_name = "SDL3";
const sdl_macos_dylib = vendor_release_dir ++ "/libSDL3.0.dylib";
const sdl_linux_so = vendor_release_dir ++ "/libSDL3.so.0";
const sdl_windows_dll = vendor_release_dir ++ "/SDL3.dll";

const compile_commands_script = "tools/write_compile_commands.cmake";

const shader_dir = "src/shaders";
const shader_entry = shader_dir ++ "/zen.metal";
const shader_air_name = "zen.air";
const shader_dep_name = "zen.d";
const shader_library_name = "default.metallib";

const install_bin_dir = "zig-out/bin";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // zig build vendor
    const vendor_config = b.addSystemCommand(&.{
        "cmake",
        "-S",
        vendor_source_dir,
        "-B",
        vendor_build_dir,
        "-DCMAKE_BUILD_TYPE=" ++ vendor_build_type,
        "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON",
    });

    const vendor_build = b.addSystemCommand(&.{
        "cmake",
        "--build",
        vendor_build_dir,
        "--config",
        vendor_build_type,
    });

    const compile_commands = b.addSystemCommand(&.{
        "cmake",
        "-P",
        compile_commands_script,
    });

    compile_commands.step.dependOn(&vendor_config.step);
    vendor_build.step.dependOn(&vendor_config.step);

    const compile_commands_step = b.step(
        "compile-commands",
        "Generate compile_commands.json",
    );
    compile_commands_step.dependOn(&compile_commands.step);

    const vendor_step = b.step("vendor", "Build vendor libraries");
    vendor_step.dependOn(&vendor_build.step);
    vendor_step.dependOn(&compile_commands.step);

    const sdl_translate = b.addTranslateC(.{
        .root_source_file = b.path(sdl_header),
        .target = target,
        .optimize = optimize,
    });
    sdl_translate.addIncludePath(b.path(sdl_include_dir));

    const sdl_mod = sdl_translate.createModule();

    // Public Zen module.
    const mod = b.addModule(app_name, .{
        .root_source_file = b.path(module_source),
        .target = target,
    });

    mod.link_libc = true;
    mod.addIncludePath(b.path(sdl_include_dir));
    mod.addLibraryPath(b.path(vendor_release_dir));
    mod.linkSystemLibrary(sdl_library_name, .{});
    mod.addImport("sdl", sdl_mod);

    // Application executable.
    const exe = b.addExecutable(.{
        .name = app_name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_source),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zen", .module = mod },
            },
        }),
    });

    exe.root_module.link_libc = true;
    exe.root_module.addIncludePath(b.path(sdl_include_dir));
    exe.root_module.addLibraryPath(b.path(vendor_release_dir));
    exe.root_module.linkSystemLibrary(sdl_library_name, .{});

    exe.root_module.addCSourceFile(.{
        .file = b.path(metal_source),
        .flags = &.{"-fobjc-arc"},
    });

    exe.root_module.linkFramework("Foundation", .{});
    exe.root_module.linkFramework("QuartzCore", .{});
    exe.root_module.linkFramework("Metal", .{});
    exe.root_module.linkFramework("CoreGraphics", .{});

    const metal_compile = b.addSystemCommand(&.{
        "xcrun",
        "-sdk",
        "macosx",
        "metal",
    });
    metal_compile.addArg("-I");
    metal_compile.addDirectoryArg(b.path(shader_dir));
    metal_compile.addArg("-MMD");
    metal_compile.addArg("-MP");
    metal_compile.addArg("-dependency-file");
    _ = metal_compile.addDepFileOutputArg(shader_dep_name);
    metal_compile.addArg("-c");
    metal_compile.addFileArg(b.path(shader_entry));
    metal_compile.addArg("-o");
    const shader_air = metal_compile.addOutputFileArg(shader_air_name);

    const metal_library = b.addSystemCommand(&.{
        "xcrun",
        "-sdk",
        "macosx",
        "metallib",
    });
    metal_library.addFileArg(shader_air);
    metal_library.addArg("-o");
    const shader_library = metal_library.addOutputFileArg(shader_library_name);

    const install_shader_library = b.addInstallFileWithDir(
        shader_library,
        .bin,
        shader_library_name,
    );
    b.getInstallStep().dependOn(&install_shader_library.step);

    const shaders_step = b.step("shaders", "Build Metal shader library");
    shaders_step.dependOn(&metal_library.step);

    // Configure runtime lookup and install the appropriate shared library.
    switch (target.result.os.tag) {
        .macos => {
            exe.root_module.addRPath(.{
                .cwd_relative = "@loader_path",
            });

            const install_sdl = b.addInstallFileWithDir(
                b.path(sdl_macos_dylib),
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
                b.path(sdl_linux_so),
                .bin,
                "libSDL3.so.0",
            );

            b.getInstallStep().dependOn(&install_sdl.step);
        },

        .windows => {
            const install_sdl = b.addInstallFileWithDir(
                b.path(sdl_windows_dll),
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
            run_cmd.setCwd(b.path(install_bin_dir));
            run_cmd.setEnvironmentVariable(
                "DYLD_LIBRARY_PATH",
                ".",
            );
            // run_cmd.setEnvironmentVariable(
            //     "MTL_HUD_ENABLED",
            //     "1",
            // );
        },
        .linux => {
            run_cmd.setEnvironmentVariable(
                "LD_LIBRARY_PATH",
                vendor_release_dir,
            );
        },
        .windows => {
            run_cmd.setEnvironmentVariable(
                "PATH",
                vendor_release_dir,
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
