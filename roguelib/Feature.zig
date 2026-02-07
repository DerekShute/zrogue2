//!
//! Things that are at a place and are interactive
//!

const std = @import("std");
const Entity = @import("Entity.zig");
const Pos = @import("Pos.zig");
const Map = @import("Map.zig");

const Self = @This();

//
// Action vector
//

const Callback = *const fn (entity: *Entity, map: *Map, pos: Pos) bool;

pub const VTable = struct {
    find: ?Callback = null,
    enter: ?Callback = null,
    // Take, open, climb, descend, etc.
};

//
// Members
//

// FUTURE: context
vtable: *const VTable = undefined,

//
// Methods
//

pub fn init(vtable: *const VTable) Self {
    return .{
        .vtable = vtable,
    };
}

// TODO: is there a way to convert to a comptime template?

pub fn find(self: Self, entity: *Entity, map: *Map, pos: Pos) bool {
    if (self.vtable.find) |cb| {
        return cb(entity, map, pos);
    }
    return false; // Not found
}

pub fn enter(self: Self, entity: *Entity, map: *Map, pos: Pos) bool {
    if (self.vtable.enter) |cb| {
        return cb(entity, map, pos);
    }
    return false;
}

// EOF
