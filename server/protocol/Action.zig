//!
//! Action placeholder
//!
//! TODO: need to integrate, etc. with roguelib/Action.zig
//!

const std = @import("std");

const Allocator = std.mem.Allocator;

const Self = @This();

pub const Kind = enum {
    none,
    quit,
    ascend,
    descend,
    move, // Directional
    search,
    take, // Positional
    wait,
};

kind: Kind,
x: i16, // As slice/array is a problem
y: i16,

// EOF

pub fn init(allocator: Allocator, kind: Kind, pos: []const i16) !*Self {
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

// write

test "basic usage" {
    var msg = try init(t_allocator, .none, &.{ 0, 1 });
    defer msg.deinit(t_allocator);
}

test "init, memory failure 1" {
    var f = FailingAllocator.init(t_allocator, .{ .fail_index = 0 });
    try expectError(error.OutOfMemory, init(f.allocator(), .none, &.{ 0, 1 }));
}

// EOF
