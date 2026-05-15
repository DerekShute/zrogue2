//!
//! testing rig - this allows a thorough mock approach
//!

const std = @import("std");
const game = @import("game");
const MockClient = @import("roguelib").MockClient;
const Client = @import("roguelib").Client;

//
// Unit Tests
//

var testlist = [_]Client.Command{
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

//
// TODO: this is baloney.  We no longer have access to the test mapgen.  We
// have to abstract mapgen into an interface and then it can be passed around
//

test "run the game" {
    const config: MockClient.Config = .{
        .commands = &testlist,
    };
    var m = try MockClient.init(config);
    defer m.deinit();

    var player = game.Player.init(.{
        .client = m.client(),
    });

    try game.run(.{
        .player = &player,
        .allocator = std.testing.allocator,
    });
}

//
// Breakout
//

comptime {
    _ = @import("actions.zig");
    //
    // TODO: needs thorough rework
    //
    // _ = @import("render.zig");
}

// EOF
