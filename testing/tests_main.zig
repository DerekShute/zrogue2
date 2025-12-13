//!
//! testing rig - this allows a thorough mock approach
//!

const std = @import("std");
const game = @import("game");
const MockProvider = @import("MockProvider.zig");
const ui = @import("ui");

const XSIZE = 80;
const YSIZE = 24;

//
// Unit Tests
//

var testlist = [_]ui.Provider.Command{
    .wait, // do nothing
    .go_west,
    .go_east,
    .go_north,
    .go_south,
    .ascend,
    .descend,
    .search,
    .take_item,
    .go_north,
    .go_east,
    .take_item, // gold
    .search, // find trap
    .go_east, // step on trap
    .search, // find secret door
    .go_north,
    .descend, // "level two"
    .go_north,
    .go_north,
    .go_north,
    .go_east,
    .go_east,
    .ascend, // back to "level one"
    .quit,
};

test "run the game" {
    const p_config: MockProvider.Config = .{
        .allocator = std.testing.allocator,
        .maxx = XSIZE,
        .maxy = YSIZE,
        .commands = &testlist,
    };
    var m = try MockProvider.init(p_config);
    defer m.deinit(std.testing.allocator);

    var player = game.Player.init(.{
        .provider = m.provider(),
        .allocator = std.testing.allocator,
        .maxx = XSIZE,
        .maxy = YSIZE,
    });

    try game.run(.{
        .player = &player,
        .allocator = std.testing.allocator,
        .gentype = .TEST,
    });
}

//
// Breakout
//

comptime {
    _ = @import("actions.zig");
    _ = @import("MockProvider.zig");
}

// EOF
