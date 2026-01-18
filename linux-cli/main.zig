//!
//! zrogue as CLI application
//!

const std = @import("std");
const game = @import("game");
const Curses = @import("Curses.zig");

const XSIZE = 80;
const YSIZE = 24;

//
// Main entrypoint of Linux single-player CLI using Curses
//

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

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
