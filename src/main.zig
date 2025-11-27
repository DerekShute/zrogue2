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

    var p = c.provider();

    // TODO: invoke game here

    _ = p.getCommand();
}

//
// Unit Tests
//

test "run the game" {
    var m = try ui.initMock(.{ .allocator = std.testing.allocator, .maxx = 80, .maxy = 24 });
    defer m.deinit(std.testing.allocator);

    var p = m.provider();

    // TODO: invoke game here

    _ = p.getCommand();
}

// EOF
