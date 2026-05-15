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

    const curses_mod = b.addModule("ncurses", .{
        .root_source_file = b.path("ui/NCurses/root.zig"),
        .target = target,
    });

    const ui_mod = b.addModule("rogueui", .{
        .root_source_file = b.path("ui/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "ncurses", .module = curses_mod },
        },
    });

    const connector_mod = b.addModule("connector", .{
        .root_source_file = b.path("connector/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "rogueui", .module = ui_mod },
        },
    });

    const roguelib_mod = b.addModule("roguelib", .{
        .root_source_file = b.path("roguelib/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "rogueui", .module = ui_mod },
        },
    });

    const game_mod = b.addModule("game", .{
        .root_source_file = b.path("game/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "roguelib", .module = roguelib_mod },
        },
    });

    //
    // Rogue single-user CLI
    //

    const rogue_exe = b.addExecutable(.{
        .name = "rogue",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/linux-zrogue/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "game", .module = game_mod },
                .{ .name = "roguelib", .module = roguelib_mod },
                .{ .name = "rogueui", .module = ui_mod },
            },
            .link_libc = true,
        }),
    });

    rogue_exe.root_module.addOptions("build", options); // exposes version
    rogue_exe.root_module.linkSystemLibrary("ncursesw", .{});
    b.installArtifact(rogue_exe);

    //
    // Rogue server
    //

    const server_exe = b.addExecutable(.{
        .name = "server",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/linux-server/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "connector", .module = connector_mod },
                .{ .name = "game", .module = game_mod },
                .{ .name = "roguelib", .module = roguelib_mod },
            },
        }),
    });

    b.installArtifact(server_exe);

    const fuzz_exe = b.addExecutable(.{
        .name = "fuzz",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/fuzz/main.zig"),
            .target = target,
            .optimize = test_optimize,
            .imports = &.{
                .{ .name = "connector", .module = connector_mod },
                .{ .name = "roguelib", .module = roguelib_mod },
            },
        }),
    });

    b.installArtifact(fuzz_exe);

    //
    // Client
    //

    const client_exe = b.addExecutable(.{
        .name = "client",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/linux-client/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "connector", .module = connector_mod },
                .{ .name = "rogueui", .module = ui_mod },
                .{ .name = "roguelib", .module = roguelib_mod },
            },
            .link_libc = true,
        }),
    });

    client_exe.root_module.linkSystemLibrary("ncursesw", .{});
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

    //
    // Tests
    //

    const connector_tests = b.addTest(.{
        .root_module = connector_mod,
    });
    const run_connector_tests = b.addRunArtifact(connector_tests);

    const roguelib_tests = b.addTest(.{
        .root_module = roguelib_mod,
    });
    const run_roguelib_tests = b.addRunArtifact(roguelib_tests);

    const game_tests = b.addTest(.{
        .root_module = game_mod,
    });
    const run_game_tests = b.addRunArtifact(game_tests);

    // Test build target
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_connector_tests.step);
    test_step.dependOn(&run_roguelib_tests.step);
    test_step.dependOn(&run_game_tests.step);

    //
    // Visualization
    //

    const viz = b.addExecutable(.{
        .name = "visualization",
        .root_module = b.createModule(.{
            .root_source_file = b.path("roguelib/vis_main.zig"),
            .target = target,
            .optimize = test_optimize,
            .imports = &.{
                .{ .name = "roguelib", .module = roguelib_mod },
                .{ .name = "rogueui", .module = ui_mod },
            },
        }),
    });
    b.installArtifact(viz);
    const viz_cmd = b.addRunArtifact(viz);

    // Visualization build target
    const viz_step = b.step("visual", "Create Visualization");
    viz_step.dependOn(&viz_cmd.step);
}

// EOF
