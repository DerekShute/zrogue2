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
// ###......####......................#############
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

const game = @import("game");
const mapgen = @import("roguelib").mapgen;

//
// Fixed things at fixed locations for deterministic behavior
//

pub fn create(allocator: std.mem.Allocator, player: *Entity) !*Map {
    var map = try Map.init(allocator, 80, 24, 3, 2);
    errdefer map.deinit(allocator);

    var room = Room.config(Pos.config(2, 2), Pos.config(9, 9));
    room.setDark();
    mapgen.addRoom(map, room);

    mapgen.addRoom(map, Room.config(Pos.config(27, 5), Pos.config(35, 10)));
    mapgen.addEastCorridor(map, Pos.config(9, 5), Pos.config(27, 8), 13);

    mapgen.addRoom(map, Room.config(Pos.config(4, 12), Pos.config(20, 19)));

    mapgen.addSouthCorridor(map, Pos.config(4, 9), Pos.config(18, 12), 10);

    mapgen.addItemToMap(map, Pos.config(7, 5), .gold);

    map.setFloorTile(Pos.config(8, 4), .stairs_down);
    map.setFloorTile(Pos.config(8, 3), .stairs_up);

    game.addSecretDoor(map, Pos.config(9, 5));
    game.addTrap(map, Pos.config(8, 5));

    mapgen.addEntityToMap(map, player, Pos.config(6, 6));

    return map;
}

// EOF
