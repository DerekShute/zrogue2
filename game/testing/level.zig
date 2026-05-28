//!
//! A defined map used for running unit tests
//!
//! Someday, this goes under kcov
//!
//! NOTE NOTE NOTE: this is of limited use until it becomes an interface
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

const game = @import("../root.zig");
const mapgen = @import("../mapgen.zig");

//
// Fixed things at fixed locations for deterministic behavior
//
// REFACTOR: remove player-entity from this
//
pub fn create(allocator: std.mem.Allocator, player: *Entity) !*Map {
    var map = try Map.init(allocator, game.XSIZE, game.YSIZE, 3, 2);
    errdefer map.deinit(allocator);

    var room = Room.config(.init(2, 2), .init(9, 9));
    room.setDark();
    mapgen.addRoom(map, room, .floor);

    mapgen.addRoom(map, Room.config(.init(27, 5), .init(35, 10)), .floor);
    mapgen.addEastCorridor(map, .init(9, 5), .init(27, 8), 13, .corridor);
    mapgen.setFloor(map, .init(27, 8), .door); // FOV requires

    mapgen.addRoom(map, Room.config(.init(4, 12), .init(20, 19)), .floor);

    mapgen.addSouthCorridor(map, .init(4, 9), .init(18, 12), 10, .corridor);
    // TODO: makeDoor not exposed and requires std.Random

    mapgen.addItem(map, .init(7, 5), .gold);

    mapgen.setFloor(map, .init(8, 4), .stairs_down);
    mapgen.setFloor(map, .init(8, 3), .stairs_up);

    // REFACTOR: consolidate namespace
    game.addSecretDoor(map, .init(9, 5));
    game.addTrap(map, .init(8, 5));

    mapgen.addEntityToMap(map, player, .init(6, 6));

    return map;
}

//
// Unit Tests (of the mapgen in general)
//

const expect = std.testing.expect;
const test_allocator = std.testing.allocator;

test "lit rooms, dark rooms, passability" {
    var entity = Entity.init(.{ .tile = .player, .vtable = &.{} });
    var map = try create(test_allocator, &entity);
    defer map.deinit(test_allocator);

    try expect(map.isPassable(.init(9, 5)) == false); // unfound secret door
    try expect(map.isPassable(.init(8, 5)) == true); // unfound trap
    try expect(map.isPassable(.init(8, 4)) == true); // stairs down
    try expect(map.isPassable(.init(8, 3)) == true); // stairs up
    try expect(map.isPassable(.init(8, 15)) == true); // room
}
// EOF
