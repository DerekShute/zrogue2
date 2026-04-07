//!
//! Depart (either side) : player is leaving or is booted
//!
//!   message : max 80 characters
//!

const std = @import("std");

const Self = @This();

pub const max_message_len = 80;

//
// Members : do not supply defaults!
//

message: []const u8,

//
// Lifecycle
//

pub fn init(allocator: std.mem.Allocator, message: []const u8) !*Self {
    if (message.len > max_message_len) {
        @panic("Depart.init: message too long"); // Prevent this, please
    }
    const s: *Self = try allocator.create(Self);
    errdefer allocator.destroy(s);
    s.message = try allocator.dupe(u8, message);
    return s;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    allocator.free(self.message);
    allocator.destroy(self);
}

pub fn valid(self: *Self) bool {
    if (self.message.len > max_message_len) {
        return false;
    }
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
    var msg = try init(t_allocator, "a message");
    defer msg.deinit(t_allocator);
}

test "validation" {
    const text: []const u8 = "*" ** (max_message_len + 1);

    const dup = try t_allocator.dupe(u8, text);
    defer t_allocator.free(dup);

    var msg = Self{ .message = dup };
    try expect(!valid(&msg));
}

test "init, memory failure 1" {
    var f = FailingAllocator.init(t_allocator, .{ .fail_index = 0 });
    try expectError(error.OutOfMemory, init(f.allocator(), "doesnotmatter"));
}

test "init, memory failure 2" {
    var f = FailingAllocator.init(t_allocator, .{ .fail_index = 1 });
    try expectError(error.OutOfMemory, init(f.allocator(), "doesnotmatter"));
}

// EOF
