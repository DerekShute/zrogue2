//!
//! zrogue as CLI application
//!

const std = @import("std");
const lib = @import("roguelib");
const ui = @import("ui");

const run_game = @import("game").run_game;

//
// Main entrypoint of Linux single-player CLI using Curses
//

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var c = ui.initCurses(.{ .allocator = allocator, .maxx = 80, .maxy = 24 }) catch |err| switch (err) {
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

    run_game(c.provider());
}

//
// Unit Tests
//

test "run the game" {
    var m = try ui.initMock(.{ .allocator = std.testing.allocator, .maxx = 80, .maxy = 24 });
    defer m.deinit(std.testing.allocator);

    run_game(m.provider());
}

// EOF
