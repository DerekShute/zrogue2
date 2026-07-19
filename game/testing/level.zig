//!
//! A defined map used for running unit tests
//!
//! Someday, this goes under kcov
//!
//! Player starts at 6,6 but this is handled in the State init
//!

// ################################################
// ################################################
// ################################################
// ###.....<#######################################
// ###.....>#######################################
// ###....$^+....##################################
// ###...@..####.##############.......#############
// ###......####.##############.......#############
// ###......####..............+.......#############
// ####.#######################.......#############
// ####...............#############################
// ##################.#############################
// ##################.#############################
// #####...............############################
// #####...............############################
// #####...............############################
// #####...............############################
// #####...............############################
// #####...............############################
// ################################################

const std = @import("std");
const Entity = @import("roguelib").Entity;
const Map = @import("roguelib").Map;
const Pos = @import("roguelib").Pos;
const Room = @import("roguelib").Room;

const mapgen = @import("../mapgen.zig");

//
// Fixed things at fixed locations for deterministic behavior
//
// REFACTOR: remove player-entity from this
//
pub fn create(allocator: std.mem.Allocator) !*Map {
    var map = try mapgen.create(allocator, 3, 2);
    errdefer map.deinit(allocator);

    var room = Room.config(.init(2, 2), .init(9, 9));
    room.setDark();
    mapgen.addRoom(map, room);

    mapgen.addRoom(map, Room.config(.init(27, 5), .init(35, 10)));
    mapgen.addEastCorridor(map, .init(9, 5), .init(27, 8), 13);
    mapgen.setFloor(map, .init(27, 8), .door); // FOV requires

    mapgen.addRoom(map, Room.config(.init(4, 12), .init(20, 19)));

    mapgen.addSouthCorridor(map, .init(4, 9), .init(18, 12), 10);
    // TODO: makeDoor not exposed and requires std.Random

    mapgen.addItem(map, .init(7, 5), .gold);

    mapgen.setFloor(map, .init(8, 4), .stairs_down);
    mapgen.setFloor(map, .init(8, 3), .stairs_up);

    mapgen.addSecretDoor(map, .init(9, 5));
    mapgen.addTrap(map, .init(8, 5));

    return map;
}

//
// Unit Tests (of the mapgen in general)
//

const expect = std.testing.expect;
const test_allocator = std.testing.allocator;

test "lit rooms, dark rooms, passability" {
    var map = try create(test_allocator);
    defer map.deinit(test_allocator);

    try expect(map.isPassable(.init(9, 5)) == false); // unfound secret door
    try expect(map.isPassable(.init(8, 5)) == true); // unfound trap
    try expect(map.isPassable(.init(8, 4)) == true); // stairs down
    try expect(map.isPassable(.init(8, 3)) == true); // stairs up
    try expect(map.isPassable(.init(8, 15)) == true); // room
}
// EOF
