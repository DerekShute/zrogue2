//!
//! Rogue Field-of-Vision logic
//!
//! FUTURE: an interface given to the game to the entity
//!

const std = @import("std");

const Entity = @import("roguelib").Entity;
const Map = @import("roguelib").Map;
const Pos = @import("roguelib").Pos;
const Region = @import("roguelib").Region;

//
// Adjust the view, going from where the Entity was to where it is now.
//
pub fn adjust(entity: *Entity, map: *Map, old_pos: Pos) void {
    const new_pos = entity.getPos();
    const new_floor = map.getFloorTile(new_pos);
    const old_floor = map.getFloorTile(old_pos);
    const new_lit = map.isLit(new_pos);
    const old_lit = map.isLit(old_pos);

    if ((old_floor == .door) and (new_floor == .floor)) {
        // Into the room properly
        entity.setRegionVisible(.configRadius(old_pos, 1), false);
    } else if ((new_floor == .door) and (old_floor == .corridor)) {
        // Into threshold
        entity.setRegionVisible(.configRadius(old_pos, 1), false);
        enterRoom(entity, map);
    } else if ((new_floor == .corridor) and (old_floor == .door)) {
        // Leaving threshold and into dark corridor
        leaveRoom(entity, map, old_pos);
    } else if (!new_lit and !old_lit) {
        // Moving around in a corridor or a dark room
        entity.setRegionVisible(.configRadius(old_pos, 1), false);
    }
    entity.setRegionVisible(.configRadius(new_pos, 1), true);
}

pub fn enterRoom(entity: *Entity, map: *Map) void {
    if (map.isLit(entity.getPos())) {
        // Entering a lit room : update what is now visible
        if (map.getRoomRegion(entity.getPos())) |region| {
            entity.setRegionVisible(region, true);
        }
    }

    // FUTURE: triggers for monsters, etc.
}

pub fn leaveRoom(entity: *Entity, map: *Map, old_pos: Pos) void {
    if (map.isLit(old_pos)) {
        // Leaving a lit room : update what is now visible
        if (map.getRoomRegion(old_pos)) |region| {
            entity.setRegionVisible(region, false);
        }
    }

    // FUTURE: triggers for monsters, etc.
}

// EOF
