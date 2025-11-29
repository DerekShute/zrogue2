//!
//! Build control file
//!
//! Taken from 'zig init' and hammered to fit
//!

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    // ziglang #24165: linker problems when the system library (ncurses) is a
    // linker script.  For now hammer to ReleaseFast to avoid and move forward
    //
    //    const optimize = b.standardOptimizeOption(.{});
    const optimize = .ReleaseFast;

    const roguelib_mod = b.addModule("roguelib", .{
        .root_source_file = b.path("roguelib/root.zig"),
        .target = target,
    });

    const ui_mod = b.addModule("ui", .{
        .root_source_file = b.path("ui/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "roguelib", .module = roguelib_mod },
        },
    });

    const mapgen_mod = b.addModule("mapgen", .{
        .root_source_file = b.path("mapgen/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "roguelib", .module = roguelib_mod },
        },
    });

    const game_mod = b.addModule("game", .{
        .root_source_file = b.path("game/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "mapgen", .module = mapgen_mod },
            .{ .name = "roguelib", .module = roguelib_mod },
            .{ .name = "ui", .module = ui_mod },
        },
    });

    const exe = b.addExecutable(.{
        .name = "zrogue",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "game", .module = game_mod },
                .{ .name = "roguelib", .module = roguelib_mod },
                .{ .name = "ui", .module = ui_mod },
            },
        }),
    });

    exe.linkLibC();
    exe.linkSystemLibrary("ncursesw");
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const roguelib_tests = b.addTest(.{
        .root_module = roguelib_mod,
    });
    const run_roguelib_tests = b.addRunArtifact(roguelib_tests);

    const mapgen_tests = b.addTest(.{
        .root_module = mapgen_mod,
    });
    const run_mapgen_tests = b.addRunArtifact(mapgen_tests);

    const ui_tests = b.addTest(.{
        .root_module = ui_mod,
    });
    const run_ui_tests = b.addRunArtifact(ui_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
    test_step.dependOn(&run_mapgen_tests.step);
    test_step.dependOn(&run_roguelib_tests.step);
    test_step.dependOn(&run_ui_tests.step);
}

// EOF
