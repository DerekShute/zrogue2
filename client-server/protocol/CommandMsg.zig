//!
//! Action message
//!
//! msgpack-safe
//!

const std = @import("std");
const Command = @import("roguelib").Client.Command;

const Allocator = std.mem.Allocator;
const Self = @This();

//
// Members
//

c: Command,

pub fn init(allocator: Allocator, command: Command) !*Self {
    const s: *Self = try allocator.create(Self);
    errdefer allocator.destroy(s);
    s.c = command;
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
    var msg = try init(t_allocator, .wait);
    defer msg.deinit(t_allocator);
}

test "init, memory failure 1" {
    var f = FailingAllocator.init(t_allocator, .{ .fail_index = 0 });
    try expectError(error.OutOfMemory, init(f.allocator(), .wait));
}

// EOF
