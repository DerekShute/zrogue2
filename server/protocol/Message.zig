//!
//! Message (from server)
//!   For now, only boring game-action related
//!
//!   message : max 80 characters
//!

const std = @import("std");

const Self = @This();

pub const max_message_len = 80;

//
// Members: do not supply defaults!
//

message: []const u8,

//
// Lifecycle
//

pub fn init(allocator: std.mem.Allocator, message: []const u8) !*Self {
    if (message.len > max_message_len) {
        @panic("Message.init: message too long"); // Prevent this, please
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
    if (self.message.len > max_message_len) { // Borderline but enforce
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

const test_msg: *const [max_message_len:0]u8 = "*" ** max_message_len;

const msgpack = @import("msgpack");

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

test "memory failure 1" {
    var f = FailingAllocator.init(t_allocator, .{ .fail_index = 0 });
    try expectError(error.OutOfMemory, init(f.allocator(), "doesnotmatter"));
}

test "memory failure 2" {
    var f = FailingAllocator.init(t_allocator, .{ .fail_index = 1 });
    try expectError(error.OutOfMemory, init(f.allocator(), "doesnotmatter"));
}

// EOF
