//!
//! Map features
//!

const std = @import("std");
const Entity = @import("roguelib").Entity;
const Feature = @import("roguelib").Feature;
const Pos = @import("roguelib").Pos;
const Map = @import("roguelib").Map;

//
// Action vector
//

const Callback = *const fn (entity: *Entity, map: *Map, pos: Pos) bool;

const VTable = struct {
    find: ?Callback,
    enter: ?Callback,
    // Take, open, etc.
};

//
// Secret Door
//

fn findSecretDoor(entity: *Entity, m: *Map, p: Pos) bool {
    // TODO: chance to succeed
    m.setFloorTile(p, .door);
    m.setFeature(p, .none);
    entity.setKnown(m, p, true);
    // TODO message
    return true; // Found
}

const secretdoor_vtable: VTable = .{
    .find = findSecretDoor,
    .enter = null,
};

//
// Trap
//

fn findTrap(entity: *Entity, m: *Map, p: Pos) bool {
    // TODO: chance to succeed
    if (m.getFloorTile(p) == .floor) {
        m.setFloorTile(p, .trap);
        entity.setKnown(m, p, true);
        return true; // Found
    }
    return false;
}

fn enterTrap(entity: *Entity, m: *Map, p: Pos) bool {
    // TODO: chance to avoid
    m.setFloorTile(p, .trap);
    entity.addMessage("You step on a trap!");
    // TODO: increment moves or something
    return true;
}

const trap_vtable: VTable = .{
    .find = findTrap,
    .enter = enterTrap,
};

//
// Dispatch routines
//

pub fn find(entity: *Entity, map: *Map, pos: Pos) bool {
    const feature = map.getFeature(pos);
    const dispatch: ?Callback = switch (feature) {
        .secret_door => secretdoor_vtable.find,
        .trap => trap_vtable.find,
        else => null,
    };

    if (dispatch) |cb| {
        return cb(entity, map, pos);
    }
    return false;
}

pub fn enter(entity: *Entity, map: *Map, pos: Pos) bool {
    const feature = map.getFeature(pos);
    const dispatch: ?Callback = switch (feature) {
        .secret_door => secretdoor_vtable.enter,
        .trap => trap_vtable.enter,
        else => null,
    };

    if (dispatch) |cb| {
        return cb(entity, map, pos);
    }
    return false;
}

//
// Unit tests
//

// TODO: tricky

// EOF
