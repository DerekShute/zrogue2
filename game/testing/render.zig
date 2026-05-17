//!
//! Testing map rendering
//!
//! This is kind of a bug fountain
//!

const std = @import("std");
const game = @import("game");
const Pos = @import("roguelib").Pos;
const MapTile = @import("roguelib").MapTile;

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
    try state.expectItem(Pos.config(6, 6), .unknown);

    try state.expectVisible(7, 5);
    try state.expectFloor(Pos.config(7, 5), .floor);
    try state.expectItem(Pos.config(7, 5), .gold);

    try state.expectNotVisible(8, 4); // Stairs down not in view

    // Up against the wall of the dark room

    //       ###
    //       .@<
    //       ..>

    state.moveTo(Pos.config(7, 3));
    try state.expectNotVisible(6, 6);
    try state.expectVisible(8, 4);
    try state.expectFloor(Pos.config(8, 4), .stairs_down);
    try state.expectVisible(8, 3);
    try state.expectFloor(Pos.config(8, 3), .stairs_up);

    // Lit room

    //                            #########
    //                            #.......#
    //                            #...@...#
    //                            ........#
    //                            #.......#
    //                            #########

    state.moveTo(Pos.config(31, 7));
    try state.expectVisible(27, 5);
    try state.expectFloor(Pos.config(27, 5), .wall);
    try state.expectVisible(27, 10);
    try state.expectFloor(Pos.config(27, 10), .wall);
    try state.expectVisible(35, 5);
    try state.expectFloor(Pos.config(35, 5), .wall);
    try state.expectVisible(35, 10);
    try state.expectFloor(Pos.config(35, 10), .wall);
    try state.expectVisible(31, 7);
    try state.expectFloor(Pos.config(31, 7), .floor);

    // Left the room; contents not visible

    //                            #########
    //                            #       #
    //                          ###       #
    //                          .@.       #
    //                          ###       #
    //                            #########

    state.moveTo(Pos.config(28, 8));
    try state.expectNotVisible(25, 8);
    try state.expectVisible(31, 7);
    try state.expectFloor(Pos.config(31, 7), .floor);

    // Threshold of room

    //                            #########
    //                            #.......#
    //                          ###.......#
    //                           .@.......#
    //                          ###.......#
    //                            #########

    state.moveTo(Pos.config(27, 8));
    try state.expectNotVisible(25, 8);
    try state.expectVisible(31, 7);
    try state.expectFloor(Pos.config(31, 7), .floor);

    // Fully inside room

    //                            #########
    //                            #.......#
    //                          ###.......#
    //                            .@......#
    //                          ###.......#
    //                            #########

    state.moveTo(Pos.config(28, 8));
    try state.expectNotVisible(26, 8);
    try state.expectVisible(31, 7);
    try state.expectFloor(Pos.config(31, 7), .floor);
}

// EOF
