//!
//! Action message
//!
//! msgpack-safe
//!

const std = @import("std");
const Action = @import("roguelib").Action;

const Allocator = std.mem.Allocator;
const Self = @This();

pub const Type = Action.Type;

//
// Members
//

kind: Type,
x: i16, // Slice/array is a problem for msgpack
y: i16,

pub fn init(allocator: Allocator, kind: Type, pos: []const i16) !*Self {
    const s: *Self = try allocator.create(Self);
    errdefer allocator.destroy(s);
    s.kind = kind;
    s.x = pos[0];
    s.y = pos[1];
    return s;
}

pub fn deinit(self: *Self, allocator: Allocator) void {
    allocator.destroy(self);
}

pub fn valid(self: *Self) bool {
    _ = self;
    return true;
}

//
// Unit testing
//

const expect = std.testing.expect;
const expectError = std.testing.expectError;
const t_allocator = std.testing.allocator;
const FailingAllocator = std.testing.FailingAllocator;

test "basic usage" {
    var msg = try init(t_allocator, .none, &.{ 0, 1 });
    defer msg.deinit(t_allocator);
}

test "init, memory failure 1" {
    var f = FailingAllocator.init(t_allocator, .{ .fail_index = 0 });
    try expectError(error.OutOfMemory, init(f.allocator(), .none, &.{ 0, 1 }));
}

// EOF
