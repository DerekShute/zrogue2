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
// Set the rectangular region as visible or invisible
//

fn renderRegion(entity: *Entity, r: Region, visible: bool) void {
    var _r = r; // ditch const
    var ri = _r.iterator();
    while (ri.next()) |p| {
        entity.setPosVisible(p, visible);
    }
}

//
// Render the view, going from where the Entity was to where it is now
//
pub fn revealMap(entity: *Entity, map: *Map, old_pos: Pos) void {

    // Border-of-room and in-corridor hack
    renderRegion(entity, .configRadius(old_pos, 1), false);

    // TODO: only if former != now

    if (map.getRoomRegion(old_pos)) |former| {
        // Leaving a lit room : update that it is not visible
        if (map.isLit(old_pos)) {
            renderRegion(entity, former, false);
        }
    }
    if (map.getRoomRegion(entity.getPos())) |now| {
        // Entering or already in a lit room : update
        if (map.isLit(entity.getPos())) {
            renderRegion(entity, now, true);
        }
    }

    // Doorways and hallways need explicit
    renderRegion(entity, .configRadius(entity.getPos(), 1), true);
}

// EOF
