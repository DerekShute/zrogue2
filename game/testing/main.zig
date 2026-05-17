//!
//! Test the end-to-end
//!

const std = @import("std");
const game = @import("../root.zig");
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

test "run the game" {
    var m = try MockClient.init();
    defer m.deinit();
    m.setCommandList(&testlist);

    var player = game.Player.init(.{
        .client = m.client(),
    });

    try game.run(.{
        .player = &player,
        .allocator = std.testing.allocator,
    });
}

// EOF
