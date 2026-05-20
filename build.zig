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

    const common_mod = b.addModule("common", .{
        .root_source_file = b.path("roguelib/common.zig"),
        .target = target,
    });

    const curses_mod = b.addModule("ncurses", .{
        .root_source_file = b.path("ui/NCurses/root.zig"),
        .target = target,
    });

    const roguelib_mod = b.addModule("roguelib", .{
        .root_source_file = b.path("roguelib/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "common", .module = common_mod },
        },
    });

    // The rogue personality on top of curses

    const rogue_ui_mod = b.addModule("rogue-ui", .{
        .root_source_file = b.path("game/ui.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "ncurses", .module = curses_mod },
            .{ .name = "common", .module = common_mod },
        },
    });

    const connector_mod = b.addModule("connector", .{
        .root_source_file = b.path("connector/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "common", .module = common_mod },
        },
    });

    const game_mod = b.addModule("game", .{
        .root_source_file = b.path("game/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "roguelib", .module = roguelib_mod },
            .{ .name = "common", .module = common_mod },
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
                .{ .name = "ui", .module = rogue_ui_mod },
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

    //
    // 'fuzz tester' (not really)
    //

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
    // Client via NCurses
    //

    const client_exe = b.addExecutable(.{
        .name = "client",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/linux-client/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "connector", .module = connector_mod },
                .{ .name = "ui", .module = rogue_ui_mod },
            },
            .link_libc = true,
        }),
    });
    client_exe.root_module.linkSystemLibrary("ncursesw", .{});
    b.installArtifact(client_exe);

    //
    // Tests
    //

    const connector_tests = b.addRunArtifact(
        b.addTest(.{ .root_module = connector_mod }),
    );
    const roguelib_tests = b.addRunArtifact(
        b.addTest(.{ .root_module = roguelib_mod }),
    );
    const game_tests = b.addRunArtifact(
        b.addTest(.{ .root_module = game_mod }),
    );
    const common_tests = b.addRunArtifact(
        b.addTest(.{ .root_module = common_mod }),
    );

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&connector_tests.step);
    test_step.dependOn(&roguelib_tests.step);
    test_step.dependOn(&game_tests.step);
    test_step.dependOn(&common_tests.step);

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
                .{ .name = "common", .module = common_mod },
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
