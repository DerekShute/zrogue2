//!
//! A defined map used for running unit tests
//!
//! Someday, this goes under kcov
//!

// ################################################
// ################################################
// ################################################
// ###.....<#######################################
// ###.....>#######################################
// ###....$......##################################
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
const Map = @import("roguelib").Map;
const Pos = @import("roguelib").Pos;
const Room = @import("roguelib").Room;

const utils = @import("utils.zig");

//
// Fixed things at fixed locations for deterministic behavior
//

pub fn create(config: utils.Config, allocator: std.mem.Allocator) !*Map {
    var map = try Map.init(allocator, 80, 24, 3, 2);
    errdefer map.deinit(allocator);

    var room = Room.config(Pos.config(2, 2), Pos.config(9, 9));
    room.setDark();
    utils.addRoom(map, room);

    utils.addRoom(map, Room.config(Pos.config(27, 5), Pos.config(35, 10)));
    utils.addEastCorridor(map, Pos.config(9, 5), Pos.config(27, 8), 13);

    utils.addRoom(map, Room.config(Pos.config(4, 12), Pos.config(20, 19)));

    utils.addSouthCorridor(map, Pos.config(4, 9), Pos.config(18, 12), 10);

    utils.addItemToMap(map, Pos.config(7, 5), .gold);

    map.setFloorTile(Pos.config(8, 4), .stairs_down);
    map.setFloorTile(Pos.config(8, 3), .stairs_up);

    if (config.player) |p| {
        utils.addEntityToMap(map, p, Pos.config(6, 6));
    }

    return map;
}

// EOF
