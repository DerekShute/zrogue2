//!
//! zrogue as CLI application
//!

const std = @import("std");
const lib = @import("roguelib");
const ui = @import("ui");

//
// Main entrypoint of Linux single-player CLI using Curses
//

pub fn main() !void {
    var c = ui.initCurses(.{ .maxx = 80, .maxy = 24 }) catch |err| switch (err) {
        error.DisplayTooSmall => {
            std.debug.print("Zrogue requires an 80x24 display\n", .{});
            std.process.exit(1);
        },
        else => {
            std.debug.print("got error: {s}\n", .{@errorName(err)});
            std.process.exit(1);
        },
    };
    defer c.deinit();

    var p = c.provider();

    // TODO: invoke game here

    _ = p.getCommand();
}

//
// Unit Tests
//

test "run the game" {
    var m = ui.initMock(.{ .maxx = 80, .maxy = 24 });
    defer m.deinit();

    var p = m.provider();

    // TODO: invoke game here

    _ = p.getCommand();
}

// EOF
