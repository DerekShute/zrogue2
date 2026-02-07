//!
//! Map features
//!

const std = @import("std");
const Entity = @import("roguelib").Entity;
const Feature = @import("roguelib").Feature;
const Pos = @import("roguelib").Pos;
const Map = @import("roguelib").Map;

//
// Secret Door
//

fn findSecretDoor(entity: *Entity, m: *Map, p: Pos) bool {
    // TODO: chance to succeed
    m.setFloorTile(p, .door);
    m.setFeature(p, null);
    entity.setKnown(m, p, true);
    // TODO message
    return true; // Found
}

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

//
// Interface
//

const secret_vtable: Feature.VTable = .{
    .find = findSecretDoor,
};

pub fn addSecretDoor(m: *Map, p: Pos) void {
    m.setFloorTile(p, .wall);
    m.setFeature(p, .{ .vtable = &secret_vtable });
}

const trap_vtable: Feature.VTable = .{
    .find = findTrap,
    .enter = enterTrap,
};

pub fn addTrap(m: *Map, p: Pos) void {
    m.setFloorTile(p, .floor);
    m.setFeature(p, .{ .vtable = &trap_vtable });
}

pub fn initTrap() Feature {
    return .{
        .vtable = .{
            .find = findTrap,
            .enter = enterTrap,
        },
    };
}

//
// Unit tests
//

// TODO: still tricky

// EOF
