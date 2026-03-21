//!
//! Table update - key value
//!
//! <table name> <table entry> <value>
//!

const std = @import("std");

const Self = @This();

pub const max_len = 20;

//
// Members: do not supply defaults!
//

table: []const u8,
entry: []const u8,
value: []const u8,

pub fn init(allocator: std.mem.Allocator, table: []const u8, entry: []const u8, value: []const u8) !*Self {
    if ((table.len > max_len) or (entry.len > max_len) or (value.len > max_len)) {
        @panic("TableUpdate.init: field too long"); // Prevent this, please
    }
    const s: *Self = try allocator.create(Self);
    errdefer allocator.destroy(s);
    s.table = try allocator.dupe(u8, table);
    errdefer allocator.free(s.table);
    s.entry = try allocator.dupe(u8, entry);
    errdefer allocator.free(s.entry);
    s.value = try allocator.dupe(u8, value);
    errdefer allocator.free(s.value);
    return s;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    allocator.free(self.value);
    allocator.free(self.entry);
    allocator.free(self.table);
    allocator.destroy(self);
}

pub fn valid(self: *Self) bool {
    if ((self.table.len > max_len) or (self.entry.len > max_len) or (self.value.len > max_len)) {
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

const test_msg: *const [max_len:0]u8 = "*" ** max_len;

test "basic usage" {
    var msg = try init(t_allocator, test_msg, test_msg, test_msg);
    defer msg.deinit(t_allocator);
}

test "memory failure 1" {
    var f = FailingAllocator.init(t_allocator, .{ .fail_index = 0 });
    const foo = init(f.allocator(), "xx", "xx", "xx");
    try expectError(error.OutOfMemory, foo);
}

test "memory failure 2" {
    var f = FailingAllocator.init(t_allocator, .{ .fail_index = 1 });
    const foo = init(f.allocator(), "xx", "xx", "xx");
    try expectError(error.OutOfMemory, foo);
}

test "memory failure 3" {
    var f = FailingAllocator.init(t_allocator, .{ .fail_index = 2 });
    const foo = init(f.allocator(), "xx", "xx", "xx");
    try expectError(error.OutOfMemory, foo);
}

test "memory failure 4" {
    var f = FailingAllocator.init(t_allocator, .{ .fail_index = 3 });
    const foo = init(f.allocator(), "xx", "xx", "xx");
    try expectError(error.OutOfMemory, foo);
}

test "allocate" {
    // Beyond the allocation scheme.  If this fails, must rework
    var f = FailingAllocator.init(t_allocator, .{ .fail_index = 4 });
    var sendmsg = try init(f.allocator(), test_msg, test_msg, test_msg);
    defer sendmsg.deinit(f.allocator());
}

test "validation" {
    // This is lame but I have nobody to blame but myself

    const bad: []const u8 = "*" ** 21;
    const dup = try t_allocator.dupe(u8, bad);
    defer t_allocator.free(dup);
    const good = try t_allocator.dupe(u8, test_msg);
    defer t_allocator.free(good);

    var msg: Self = .{
        .table = dup,
        .entry = good,
        .value = good,
    };

    try expect(!valid(&msg));

    msg.table = good;
    msg.entry = dup;

    try expect(!valid(&msg));

    msg.entry = good;
    msg.value = dup;

    try expect(!valid(&msg));
}

// EOF
