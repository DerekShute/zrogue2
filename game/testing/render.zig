//!
//! Testing map rendering
//!
//! This is kind of a bug fountain
//!

const std = @import("std");
const game = @import("game");
const Pos = @import("roguelib").Pos;
const State = @import("State.zig");

const expect = std.testing.expect;

//
// Tests: consult the test_level map
//

test "render starting position" {
    var state = try State.init(std.testing.allocator);
    defer state.deinit(std.testing.allocator);

    // Initial position: adjacent flooring is visible, else unknown

    //      ..$
    //      .@.
    //      ...

    try state.expectNotVisible(2, 2); // Edge of dark room

    try state.atXY(6, 6);
    try expect(state.getEntity(6, 6) == .player);
    try state.expectVisible(6, 6); // Player location
    try state.expectItem(.init(6, 6), .unknown);

    try state.expectVisible(7, 5);
    try state.expectFloor(.init(7, 5), .floor);
    try state.expectItem(.init(7, 5), .gold);

    try state.expectNotVisible(8, 4); // Stairs down not in view

    // Up against the wall of the dark room

    //       ###
    //       .@<
    //       ..>

    state.moveTo(.init(7, 3));
    try state.expectNotVisible(6, 6);
    try state.expectVisible(8, 4);
    try state.expectFloor(.init(8, 4), .stairs_down);
    try state.expectVisible(8, 3);
    try state.expectFloor(.init(8, 3), .stairs_up);

    // Lit room

    //                            #########
    //                            #.......#
    //                            #...@...#
    //                            +.......#
    //                            #.......#
    //                            #########

    state.moveTo(.init(26, 8)); // pacify FOV floor tile use by approaching
    state.moveTo(.init(27, 8)); // at door
    state.moveTo(.init(31, 7));
    try state.expectVisible(27, 5);
    try state.expectFloor(.init(27, 8), .door);
    try state.expectFloor(.init(27, 5), .wall);
    try state.expectVisible(27, 10);
    try state.expectFloor(.init(27, 10), .wall);
    try state.expectVisible(35, 5);
    try state.expectFloor(.init(35, 5), .wall);
    try state.expectVisible(35, 10);
    try state.expectFloor(.init(35, 10), .wall);
    try state.expectVisible(31, 7);
    try state.expectFloor(.init(31, 7), .floor);

    // Left the room; contents not visible

    //                            #########
    //                            #       #
    //                          ###       #
    //                          .@+       #
    //                          ###       #
    //                            #########

    state.moveTo(.init(27, 8)); // at door: pacify FOV floor tile use
    try state.expectVisible(26, 8); // tile right outside is visible

    state.moveTo(.init(26, 8)); // now outside: room not visible
    try state.expectTileUpdates(58); // 54 for bulk of room + 4 changed at move
    try state.expectMapUpdates(13);
    try state.expectVisible(25, 8); // adjacent corridor
    try state.expectNotVisible(31, 7); // Inside room
    try state.expectFloor(.init(31, 7), .floor);

    // Threshold of room

    //                            #########
    //                            #.......#
    //                          ###.......#
    //                           _@.......#
    //                          ###.......#
    //                            #########

    state.moveTo(.init(27, 8));
    try state.expectTileUpdates(60); // 64 room, 3 outside, 3 invalidated
    try state.expectMapUpdates(18);
    try state.expectNotVisible(25, 8);
    try state.expectVisible(31, 7);
    try state.expectFloor(.init(31, 7), .floor);

    // Fully inside room

    //                            #########
    //                            #.......#
    //                          ###.......#
    //                            +@......#
    //                          ###.......#
    //                            #########

    state.moveTo(.init(28, 8));
    try state.expectTileUpdates(9);
    try state.expectMapUpdates(9); // 3 invalidated, 6 affected
    try state.expectVisible(28, 8);
    try state.expectNotVisible(26, 8);
    try state.expectVisible(31, 7);
    try state.expectFloor(.init(31, 7), .floor);

    //                            #########
    //                            #.......#
    //                          ###.......#
    //                            +.@.....#
    //                          ###.......#
    //                            #########

    state.moveTo(.init(29, 8));
    try state.expectTileUpdates(2);
    try state.expectMapUpdates(2); // leave one, move to the other
}

// EOF
