//!
//! Testing actions
//!

const std = @import("std");
const game = @import("../root.zig");
const Action = @import("roguelib").Action;
const Client = @import("roguelib").Client;
const Map = @import("roguelib").Map;
const MockClient = @import("roguelib").MockClient;
const Pos = @import("roguelib").Pos;

const State = @import("State.zig");

const expect = std.testing.expect;
const test_allocator = std.testing.allocator;

//
// Tests: consult the test_level map
//

test "in-place boring stuff then quit" {
    var testlist = [_]Client.Command{
        .wait,
        .ascend,
        .descend,
        .quit,
    };

    var state = try State.init(test_allocator, &testlist);
    defer state.deinit(test_allocator);

    try state.step(.continue_game);
    try state.step(.continue_game);
    try state.step(.continue_game);
    try state.step(.end_game);
}

test "move in a circle: all directions work" {
    var testlist = [_]Client.Command{
        .go_west,
        .go_north,
        .go_east,
        .go_south,
    };

    var state = try State.init(test_allocator, &testlist);
    defer state.deinit(test_allocator);

    try state.stepXY(.continue_game, 5, 6);
    try state.stepXY(.continue_game, 5, 5);
    try state.stepXY(.continue_game, 6, 5);
    try state.stepXY(.continue_game, 6, 6);
}

test "hit a wall" {
    var testlist = [_]Client.Command{
        .go_east,
        .go_east,
        .go_east,
    };

    var state = try State.init(test_allocator, &testlist);
    defer state.deinit(test_allocator);

    try state.stepXY(.continue_game, 7, 6);
    try state.stepXY(.continue_game, 8, 6);
    try state.stepXY(.continue_game, 8, 6); // Bonk
    try state.expectMessage("Ouch!");
}

// Expand this as capabilities add...
test "pick up gold and etc" {
    // TODO: instrument the mock client so you can insert/replace items, so
    // changing this around is easier
    var testlist = [_]Client.Command{
        .search, // find nothing
        .go_east,
        .go_north,
        .take_item, // gold
        .go_east, // on trap
        .search, // find secret door
        .go_north,
        .descend,
        .go_north,
        .ascend,
    };

    var state = try State.init(test_allocator, &testlist);
    defer state.deinit(test_allocator);

    try state.step(.continue_game);
    try state.expectMessage("You find nothing!"); // search

    try state.step(.continue_game);
    try state.step(.continue_game);

    try state.expectItem(.gold);
    try state.expectPurse(0);

    try state.step(.continue_game);
    try state.expectMessage("You pick up the gold!"); // take
    try state.expectItem(.unknown);
    try state.expectPurse(1);

    try state.step(.continue_game);
    try state.expectMessage("You step on a trap!"); // go east
    try state.expectFloor(Pos.config(8, 5), .trap);

    try state.expectFloor(Pos.config(9, 5), .wall);
    try state.step(.continue_game);
    try state.expectMessage("You find something!"); // search
    try state.expectFloor(Pos.config(9, 5), .door); // secret door

    try state.step(.continue_game);
    try state.step(.descend);
    try state.expectMessage("You go ever deeper into the dungeon...");

    try state.step(.continue_game);
    try state.step(.ascend);
    try state.expectMessage("You ascend closer to the exit...");
}

// EOF
