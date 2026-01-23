//!
//! Build control file
//!
//! Taken from 'zig init' and hammered to fit
//!

const std = @import("std");
const zon = @import("build.zig.zon");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    // ziglang #24165: linker problems when the system library (ncurses) is a
    // linker script.  For now hammer to ReleaseFast to avoid and move forward
    //
    //    const optimize = b.standardOptimizeOption(.{});
    const optimize = .ReleaseFast;
    const test_optimize = b.standardOptimizeOption(.{});

    //
    // Crystallize the version into a build option
    //
    const options = b.addOptions();
    options.addOption([]const u8, "version", zon.version);

    //
    // Modules
    //

    const roguelib_mod = b.addModule("roguelib", .{
        .root_source_file = b.path("roguelib/root.zig"),
        .target = target,
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
        },
    });

    //
    // Rogue single-user CLI
    //

    const rogue_exe = b.addExecutable(.{
        .name = "rogue",
        .root_module = b.createModule(.{
            .root_source_file = b.path("linux-cli/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "game", .module = game_mod },
                .{ .name = "roguelib", .module = roguelib_mod },
            },
        }),
    });

    rogue_exe.root_module.addOptions("build", options); // exposes version
    rogue_exe.linkLibC();
    rogue_exe.linkSystemLibrary("ncursesw");
    b.installArtifact(rogue_exe);

    //
    // Rogue server
    //

    const server_exe = b.addExecutable(.{
        .name = "server",
        .root_module = b.createModule(.{
            .root_source_file = b.path("server/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(server_exe);

    //
    // Client
    //

    const client_exe = b.addExecutable(.{
        .name = "client",
        .root_module = b.createModule(.{
            .root_source_file = b.path("client/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(client_exe);

    //
    // Run rogue
    //

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(rogue_exe);
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

    const test_exe = b.addExecutable(.{
        .name = "zrogue-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("testing/tests_main.zig"),
            .target = target,
            .optimize = test_optimize,
            .imports = &.{
                .{ .name = "game", .module = game_mod },
                .{ .name = "mapgen", .module = mapgen_mod },
                .{ .name = "roguelib", .module = roguelib_mod },
            },
        }),
    });

    // I am running out of ideas for names of all this
    const testing_exe = b.addTest(.{
        .root_module = test_exe.root_module,
    });
    const run_testing_exe = b.addRunArtifact(testing_exe);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_testing_exe.step);
    test_step.dependOn(&run_mapgen_tests.step);
    test_step.dependOn(&run_roguelib_tests.step);
}

// EOF
