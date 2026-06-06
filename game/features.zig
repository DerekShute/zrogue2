//!
//! Map features
//!

const std = @import("std");
const Entity = @import("roguelib").Entity;
const Map = @import("roguelib").Map;
const mapgen = @import("mapgen.zig");
const Player = @import("Player.zig");
const Pos = @import("roguelib").Pos;
const Feature = mapgen.Feature;

//
// Secret Door
//

fn findSecretDoor(player: *Player, m: *Map, p: Pos) bool {
    // FUTURE: chance to succeed
    // FUTURE: this entity knows, but others may not
    // FUTURE: message
    mapgen.setFloor(m, p, .door);
    m.setFeature(p, null);
    player.setPosChanged(p);

    return true; // Found
}

//
// Trap
//

fn findTrap(player: *Player, m: *Map, p: Pos) bool {
    // FUTURE: chance to succeed
    // FUTURE: this entity knows, but others may not
    if (mapgen.getFloor(m, p) == .floor) {
        mapgen.setFloor(m, p, .trap);
        player.setPosChanged(p);
        // FUTURE: message here
        return true; // Found
    }
    return false;
}

fn enterTrap(player: *Player, m: *Map, p: Pos) void {
    // FUTURE: chance to avoid
    // FUTURE: consequences
    mapgen.setFloor(m, p, .trap);
    player.setPosChanged(p);
    player.addMessage("You step on a trap!");
}

//
// Callback invocation
//

pub fn enter(player: *Player, map: *Map, pos: Pos) void {
    if (map.getFeature(pos)) |val| {
        const f: Feature = @enumFromInt(val);
        switch (f) {
            .trap => enterTrap(player, map, pos),
            .secret_door => unreachable,
        }
    }
}

pub fn find(player: *Player, map: *Map, pos: Pos) bool {
    if (map.getFeature(pos)) |val| {
        const f: Feature = @enumFromInt(val);
        return switch (f) {
            .trap => findTrap(player, map, pos),
            .secret_door => findSecretDoor(player, map, pos),
        };
    }
    return false; // NOCOMMIT: needed?
}

// FUTURE: take, open, climb, descend, etc.

// EOF
