//!
//! zrogue as CLI application
//!

const std = @import("std");
const lib = @import("roguelib");
const ui = @import("ui");

//
// Local constants
//

const ui_config: ui.MockConfig = .{ .maxx = 80, .maxy = 24 };

//
// Main entrypoint of Linux single-player CLI using Curses
//

pub fn main() !void {
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    var m = ui.initMock(ui_config);
    defer m.deinit();
}

//
// Unit Tests
//

test "run the game" {
    var m = ui.initMock(ui_config);
    defer m.deinit();
}

// EOF
