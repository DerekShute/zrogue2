//!
//! zrogue as CLI application
//!

const std = @import("std");
const game = @import("game");
const ui = @import("ui");

const XSIZE = 80;
const YSIZE = 24;

//
// Main entrypoint of Linux single-player CLI using Curses
//

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var c = ui.initCurses(.{ .allocator = allocator, .maxx = XSIZE, .maxy = YSIZE }) catch |err| switch (err) {
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
        .provider = c.provider(),
        .allocator = allocator,
        .maxx = XSIZE,
        .maxy = YSIZE,
    });

    try game.run(&player, allocator);
}

//
// Unit Tests
//

const Command = @import("roguelib").Command;

var testlist = [_]Command{
    .wait,
    .go_west,
    .quit,
};

test "run the game" {
    var m = try ui.initMock(.{ .allocator = std.testing.allocator, .maxx = XSIZE, .maxy = YSIZE, .commands = &testlist });
    defer m.deinit(std.testing.allocator);

    var player = game.Player.init(.{
        .provider = m.provider(),
        .allocator = std.testing.allocator,
        .maxx = XSIZE,
        .maxy = YSIZE,
    });

    try game.run(&player, std.testing.allocator);
}

// EOF
