//!
//! Entry Request - player introduction into game
//!
//!   name : max 32 characters (arbitrary)
//!

const std = @import("std");

const Self = @This();

pub const max_namelen = 32;

//
// Members: do not supply defaults!
//

name: []u8,
// TODO: class, race, ...

//
// Lifecycle
//

pub fn init(allocator: std.mem.Allocator, name: []const u8) !*Self {
    if (name.len > max_namelen) {
        @panic("EntryRequest.init: name too long"); // Prevent this, please
    }
    const s: *Self = try allocator.create(Self);
    errdefer allocator.destroy(s);
    s.name = try allocator.dupe(u8, name);
    return s;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    allocator.free(self.name);
    allocator.destroy(self);
}

pub fn valid(self: *Self) bool {
    if (self.name.len > max_namelen) { // Borderline but enforce
        return false;
    }
    return true;
}

//
// Unit Testing
//

const expect = std.testing.expect;
const expectError = std.testing.expectError;
const t_allocator = std.testing.allocator;
const FailingAllocator = std.testing.FailingAllocator;

const test_name: *const [max_namelen:0]u8 = "*" ** max_namelen;

test "basic usage" {
    var msg = try init(t_allocator, "a name");
    defer msg.deinit(t_allocator);
}

test "validation" {
    const text: []const u8 = "*" ** (max_namelen + 1);
    const dup = try t_allocator.dupe(u8, text);
    defer t_allocator.free(dup);

    var msg = Self{ .name = dup };
    try expect(!valid(&msg));
}

test "memory failure 1" {
    var f = FailingAllocator.init(t_allocator, .{ .fail_index = 0 });
    try expectError(error.OutOfMemory, init(f.allocator(), "doesnotmatter"));
}

test "memory failure 2" {
    var f = FailingAllocator.init(t_allocator, .{ .fail_index = 1 });
    try expectError(error.OutOfMemory, init(f.allocator(), "doesnotmatter"));
}

// EOF
