//!
//! Testing actions
//!

const std = @import("std");
const Action = @import("roguelib").Action;
const Client = @import("roguelib").Client;
const Map = @import("roguelib").Map;
const MockClient = @import("roguelib").MockClient;
const Pos = @import("roguelib").Pos;
const World = @import("roguelib").World;

const State = @import("State.zig");

const expect = std.testing.expect;
const test_allocator = std.testing.allocator;

//
// Tests: consult the test_level map
//

test "in-place boring stuff then quit" {
    var state = try State.init(test_allocator);
    defer state.deinit(test_allocator);

    try expect(state.getEntity(6, 6) == .player);
    try expect(try state.step(.wait) == .play);
    try expect(try state.step(.ascend) == .play);
    try expect(try state.step(.descend) == .play);
    try expect(try state.step(.quit) == .depart);
    try expect(state.getEntity(6, 6) == .unknown); // entity departs
}

test "move in a circle: all directions work" {
    var state = try State.init(test_allocator);
    defer state.deinit(test_allocator);

    try expect(try state.step(.go_west) == .play);
    try state.atXY(5, 6);
    try expect(try state.step(.go_north) == .play);
    try state.atXY(5, 5);
    try expect(try state.step(.go_east) == .play);
    try state.atXY(6, 5);
    try expect(try state.step(.go_south) == .play);
    try state.atXY(6, 6);
}

test "hit a wall" {
    var state = try State.init(test_allocator);
    defer state.deinit(test_allocator);

    try expect(try state.step(.go_east) == .play);
    try state.atXY(7, 6);
    try expect(try state.step(.go_east) == .play);
    try state.atXY(8, 6);
    try expect(try state.step(.go_east) == .play);
    try state.atXY(8, 6);
    try state.expectMessage("Ouch!");
}

// Expand this as capabilities add...
test "pick up gold and etc" {
    var state = try State.init(test_allocator);
    defer state.deinit(test_allocator);

    try expect(try state.step(.search) == .play);
    try state.expectMessage("You find nothing!"); // search

    try expect(try state.step(.go_east) == .play);
    try expect(try state.step(.go_north) == .play);

    try state.expectItemAtPlayer(.gold);
    try state.expectPurse(0);
    try expect(try state.step(.take_item) == .play);
    try state.expectMessage("You pick up the gold!"); // take
    try state.expectItemAtPlayer(.unknown);
    try state.expectPurse(1);

    try expect(try state.step(.go_east) == .play);
    try state.expectMessage("You step on a trap!"); // go east
    try state.expectFloor(.init(8, 5), .trap);

    try state.expectFloor(.init(9, 5), .wall);
    try expect(try state.step(.search) == .play);
    try state.expectMessage("You find something!"); // search
    try state.expectFloor(.init(9, 5), .door); // secret door

    try expect(try state.step(.go_north) == .play);
    try expect(try state.step(.descend) == .play);
    try state.expectMessage("You go ever deeper into the dungeon...");

    // Back to location 6,6
    try expect(try state.step(.go_north) == .play);
    try expect(try state.step(.go_north) == .play);
    try expect(try state.step(.go_north) == .play);
    try expect(try state.step(.go_east) == .play);
    try expect(try state.step(.go_east) == .play);
    try expect(try state.step(.ascend) == .play);
    try state.expectMessage("You ascend closer to the exit...");
}

// EOF
