//!
//! zrogue as CLI application
//!

const std = @import("std");
const game = @import("game");
const Curses = @import("Curses.zig");
const options = @import("build");

const XSIZE = 80;
const YSIZE = 24;

//
// Command arguments
//

fn arg_in_list(programarg: []u8, l: []const []const u8) bool {
    for (l) |a| {
        if (std.mem.eql(u8, programarg, a)) {
            return true;
        }
    }
    return false;
}

// Help display

const help_arg_flags = [_][]const u8{ "-h", "-help", "--help" };

fn print_help() !void {
    var stdout_writer = std.fs.File.stdout().writer(&.{}); // no buffer
    const stdout = &stdout_writer.interface; // Writer

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

fn print_version() !void {
    var stdout_writer = std.fs.File.stdout().writer(&.{}); // no buffer
    const stdout = &stdout_writer.interface; // Writer

    try stdout.print("Zrogue version {s}\n", .{options.version});
    try stdout.flush();
}

//
// Main entrypoint of Linux single-player CLI using Curses
//

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    //
    // Arguments
    //
    // Note that this does not work from 'build run'
    //

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len > 1) { // program name is args[0]
        for (args) |arg| {
            if (arg_in_list(arg, &help_arg_flags)) {
                try print_help();
                std.process.exit(0);
            }
            if (arg_in_list(arg, &version_arg_flags)) {
                try print_version();
                std.process.exit(0);
            }
        }
        try print_help();
        std.process.exit(1);
    }

    //
    // Initialize display and start program
    //

    var c = Curses.init(.{ .allocator = allocator, .maxx = XSIZE, .maxy = YSIZE }) catch |err| switch (err) {
        error.DisplayTooSmall => {
            std.debug.print("Zrogue requires an 80x24 display\n", .{});
            std.process.exit(1);
        },
        else => {
            std.debug.print("got error: {s}\n", .{@errorName(err)});
            std.process.exit(1);
        },
    };
    defer c.deinit(allocator);

    var player = game.Player.init(.{
        .client = c.client(),
        .allocator = allocator,
        .maxx = XSIZE,
        .maxy = YSIZE,
    });

    try game.run(.{
        .player = &player,
        .allocator = allocator,
        .gentype = .ROGUE,
    });
}

//
// Unit Tests
//

// Handled as part of the testing subdir rig

// EOF
