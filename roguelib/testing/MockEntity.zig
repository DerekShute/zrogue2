//!
//! Mockified Entity
//!

const std = @import("std");

const Action = @import("../Action.zig");
const Entity = @import("../Entity.zig");
const Map = @import("../Map.zig");

//
// Types
//

const vtable = Entity.VTable{
    .doAction = doAction,
};

const Self = @This();

//
// Members
//

entity: Entity = undefined, // Must be first for vtable magic
faults: bool = false,
next: ?Action.Result = null,

//
// Lifecycle
//

pub fn init() Self {
    const c = Entity.Config{
        .tile = @enumFromInt(4), // Lousy but convenient
        .vtable = &vtable,
    };

    return .{
        .entity = Entity.init(c),
    };
}

pub fn getEntity(self: *Self) *Entity {
    return &self.entity;
}

//
// Methods
//

pub fn setNext(self: *Self, result: Action.Result) void {
    self.next = result;
}

pub fn setError(self: *Self) void {
    self.faults = true;
}

//
// Vtable methods
//

fn doAction(entity: *Entity, map: *Map) !Action.Result {
    _ = map;
    const self: *Self = @ptrCast(@alignCast(entity));
    if (self.faults) {
        return error.Failed;
    }
    if (self.next) |n| {
        return n;
    }
    @panic("MockEntity: no next action");
}

//
// Unit Tests
//

const expect = std.testing.expect;
const expectError = std.testing.expectError;

test "basic use" {
    var map = try Map.init(std.testing.allocator, 20, 20, 1, 1);
    defer map.deinit(std.testing.allocator);

    var self = init();
    self.setNext(.continue_game);

    try expect(try doAction(self.getEntity(), map) == .continue_game);
}

test "action error" {
    var map = try Map.init(std.testing.allocator, 20, 20, 1, 1);
    defer map.deinit(std.testing.allocator);

    var self = init();
    self.setError();

    try expectError(error.Failed, doAction(self.getEntity(), map));
}

// EOF
