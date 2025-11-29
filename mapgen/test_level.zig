//!
//! A defined map used for running unit tests
//!
//! Someday, this goes under kcov
//!

const std = @import("std");
const Map = @import("roguelib").Map;
const Pos = @import("roguelib").Pos;
const Room = @import("roguelib").Room;

const utils = @import("utils.zig");

//
// Fixed things at fixed locations for deterministic behavior
//

pub fn create(config: utils.Config, allocator: std.mem.Allocator) !*Map {
    _ = config;
    var map = try Map.init(allocator, 80, 24, 3, 2);
    errdefer map.deinit(allocator);

    var room = Room.config(Pos.config(2, 2), Pos.config(9, 9));
    room.setDark();
    utils.addRoom(map, room);

    utils.addRoom(map, Room.config(Pos.config(27, 5), Pos.config(35, 10)));
    try utils.addEastCorridor(map, Pos.config(9, 5), Pos.config(27, 8), 13);

    utils.addRoom(map, Room.config(Pos.config(4, 12), Pos.config(20, 19)));

    try utils.addSouthCorridor(map, Pos.config(4, 9), Pos.config(18, 12), 10);

    return map;
}

// EOF
