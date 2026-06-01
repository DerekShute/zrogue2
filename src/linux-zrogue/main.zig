//!
//! zrogue as CLI application
//!

const std = @import("std");
const Game = @import("game");
const Curses = @import("Curses.zig");
const options = @import("build");

//
// Command arguments
//

fn arg_in_list(programarg: []const u8, l: []const []const u8) bool {
    for (l) |a| {
        if (std.mem.eql(u8, programarg, a)) {
            return true;
        }
    }
    return false;
}

// Help display

const help_arg_flags = [_][]const u8{ "-h", "-help", "--help" };

fn print_help(init: std.process.Init) !void {
    var stdout_writer = std.Io.File.stdout().writer(init.io, &.{});
    const stdout = &stdout_writer.interface;

    const help =
        \\
        \\ This program requires a 80x24 text display.
        \\
        \\ options:
        \\   --help, -h : help
        \\   --version, -v : version
        \\
        \\ Press '?' for in-game help
        \\
    ;
    try stdout.print("Zrogue : Adventuring in the Dungeons of Doom\n", .{});
    try stdout.print(" version {s}\n", .{options.version});
    try stdout.print("{s}\n", .{help});
    try stdout.flush();
}

// Version display

const version_arg_flags = [_][]const u8{ "-v", "-version", "--version" };

fn print_version(init: std.process.Init) !void {
    var stdout_writer = std.Io.File.stdout().writer(init.io, &.{});
    const stdout = &stdout_writer.interface; // Writer

    try stdout.print("Zrogue version {s}\n", .{options.version});
    try stdout.flush();
}

//
// Main entrypoint of Linux single-player CLI using Curses
//

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    //
    // Arguments
    //
    // Note that this does not work from 'build run'
    //

    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len > 1) { // program name is args[0]
        for (args) |arg| {
            if (arg_in_list(arg[0..], &help_arg_flags)) {
                try print_help(init);
                std.process.exit(0);
            }
            if (arg_in_list(arg[0..], &version_arg_flags)) {
                try print_version(init);
                std.process.exit(0);
            }
        }
        try print_help(init);
        std.process.exit(1);
    }

    //
    // Initialize display and start program
    //

    // REFACTOR: this isn't great.  The game-ui should dictate constraints and
    // should probably give the opportunity to resize the display

    var c = Curses.init() catch |err| switch (err) {
        error.DisplayTooSmall => {
            std.debug.print(
                "Zrogue requires an {}x{} display\n",
                .{ Game.XSIZE, Game.YSIZE },
            );
            std.process.exit(1);
        },
    };
    defer c.deinit();

    var config = Game.Config.init;
    config.setAllocator(allocator);
    config.setIo(init.io);

    const seed = std.Io.Timestamp.now(init.io, .real).toMicroseconds();
    var prng = std.Random.DefaultPrng.init(@intCast(seed));
    var random = prng.random();
    config.setRandom(&random);

    var g = Game.init(config);
    defer g.deinit();

    const id = try g.initPlayer(.{ .client = c.client() });
    defer g.deinitPlayer(id);

    try g.run(g.getPlayer(id));
}

//
// Unit Tests
//

// Handled as part of the testing subdir rig

// EOF
