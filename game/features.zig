//!
//! Map features
//!

const std = @import("std");
const Feature = @import("roguelib").Feature;
const Pos = @import("roguelib").Pos;
const Map = @import("roguelib").Map;
const Player = @import("Player.zig");

//
// Action vector
//

const Callback = *const fn (map: *Map, pos: Pos, player: *Player) bool;

const VTable = struct {
    find: ?Callback,
    enter: ?Callback,
    // Take, open, etc.
};

//
// Secret Door
//

fn findSecretDoor(m: *Map, p: Pos, player: *Player) bool {
    // TODO: chance to succeed
    m.setFloorTile(p, .door);
    m.setFeature(p, .none);
    player.setKnown(p, m.getTileset(p), true);
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

fn findTrap(m: *Map, p: Pos, player: *Player) bool {
    // TODO: chance to succeed
    if (m.getFloorTile(p) == .floor) {
        m.setFloorTile(p, .trap);
        player.setKnown(p, m.getTileset(p), true);
        return true; // Found
    }
    return false;
}

fn enterTrap(m: *Map, p: Pos, player: *Player) bool {
    // TODO: chance to avoid
    m.setFloorTile(p, .trap);
    player.addMessage("You step on a trap!");
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
// TODO: is there a comptime trick?
//

pub fn find(f: Feature, m: *Map, p: Pos, player: *Player) bool {
    const dispatch: ?Callback = switch (f) {
        .secret_door => secretdoor_vtable.find,
        .trap => trap_vtable.find,
        else => null,
    };

    if (dispatch) |cb| {
        return cb(m, p, player);
    }
    return false;
}

pub fn enter(f: Feature, m: *Map, p: Pos, player: *Player) bool {
    const dispatch: ?Callback = switch (f) {
        .secret_door => secretdoor_vtable.enter,
        .trap => trap_vtable.enter,
        else => null,
    };

    if (dispatch) |cb| {
        return cb(m, p, player);
    }
    return false;
}

//
// Unit tests
//

// TODO: tricky

// EOF
