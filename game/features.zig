//!
//! Map features
//!

const std = @import("std");
const Entity = @import("roguelib").Entity;
const Pos = @import("roguelib").Pos;
const Map = @import("roguelib").Map;

//
// Enum to guide switches
//

pub const Feature = enum {
    trap,
    secret_door,
    stairs_down, // FUTURE: 'enter' or 'interact'
    stairs_up,
    // FUTURE: illusionary wall, hidden treasure
};

//
// mapgen
//

pub fn addSecretDoor(m: *Map, p: Pos) void {
    m.setFloorTile(p, .wall);
    m.setPassable(p, false);
    m.setFeature(p, @intFromEnum(Feature.secret_door));
}

pub fn addTrap(m: *Map, p: Pos) void {
    m.setFloorTile(p, .floor);
    m.setFeature(p, @intFromEnum(Feature.trap));
}

//
// Secret Door
//

fn findSecretDoor(entity: *Entity, m: *Map, p: Pos) bool {
    // FUTURE: chance to succeed
    // FUTURE: this entity knows, but others may not
    // FUTURE: message
    m.setFloorTile(p, .door);
    m.setFeature(p, null);
    m.setPassable(p, true);
    entity.setPosChanged(p);

    return true; // Found
}

//
// Trap
//

fn findTrap(entity: *Entity, m: *Map, p: Pos) bool {
    // FUTURE: chance to succeed
    // FUTURE: this entity knows, but others may not
    if (m.getFloorTile(p) == .floor) {
        m.setFloorTile(p, .trap);
        entity.setPosChanged(p);
        // FUTURE: message here
        return true; // Found
    }
    return false;
}

fn enterTrap(entity: *Entity, m: *Map, p: Pos) void {
    // FUTURE: chance to avoid
    // FUTURE: consequences
    m.setFloorTile(p, .trap);
    entity.setPosChanged(p);
    entity.addMessage("You step on a trap!");
}

//
// Callback invocation
//

pub fn enter(entity: *Entity, map: *Map, pos: Pos) void {
    if (map.getFeature(pos)) |val| {
        const f: Feature = @enumFromInt(val);
        switch (f) {
            .trap => enterTrap(entity, map, pos),
            else => {},
        }
    }
}

pub fn find(entity: *Entity, map: *Map, pos: Pos) bool {
    if (map.getFeature(pos)) |val| {
        const f: Feature = @enumFromInt(val);
        return switch (f) {
            .trap => findTrap(entity, map, pos),
            .secret_door => findSecretDoor(entity, map, pos),
            else => false,
        };
    }
    return false; // NOCOMMIT: needed?
}

// FUTURE: take, open, climb, descend, etc.

// EOF
