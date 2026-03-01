//!
//! Table update - key value
//!
//! <table name> <table entry> <value>
//!

const std = @import("std");
const utils = @import("utils.zig");

const Reader = std.io.Reader;
const Writer = std.io.Writer;
const Allocator = std.mem.Allocator;

const Self = @This();

pub const max_len = 20;

//
// Members: do not supply defaults!
//

table: []u8,
entry: []u8,
value: []u8,

pub fn copy(allocator: Allocator, basis: Self) !*Self {
    return init(allocator, basis.table, basis.entry, basis.value);
}

pub fn init(allocator: Allocator, table: []const u8, entry: []const u8, value: []const u8) !*Self {
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

pub fn deinit(self: *Self, allocator: Allocator) void {
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
// Methods
//

pub const write = utils.genericWrite;

pub fn read(reader: *Reader, allocator: Allocator) !*Self {
    return utils.genericRead(Self, reader, allocator);
}

//
// Unit testing
//

const expect = std.testing.expect;
const expectError = std.testing.expectError;
const t_allocator = std.testing.allocator;
const FailingAllocator = std.testing.FailingAllocator;

const test_msg: *const [max_len:0]u8 = "*" ** max_len;

const msgpack = @import("msgpack");

test "copy correctness" {
    var msg = try init(t_allocator, "1", "23", "456");
    defer msg.deinit(t_allocator);

    var comp = try copy(t_allocator, msg.*);
    defer comp.deinit(t_allocator);

    try expect(std.mem.eql(u8, comp.table, msg.table));
    try expect(std.mem.eql(u8, comp.entry, msg.entry));
    try expect(std.mem.eql(u8, comp.value, msg.value));
}

test "write and read" {
    var buffer: [256]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);

    var sendmsg = try init(t_allocator, test_msg, test_msg, test_msg);
    defer sendmsg.deinit(t_allocator);

    try expect(valid(sendmsg));

    try sendmsg.write(&bwriter);
    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);
    var msg = try read(&breader, t_allocator);
    defer msg.deinit(t_allocator);

    try expect(std.mem.eql(u8, msg.table, test_msg));
    try expect(std.mem.eql(u8, msg.entry, test_msg));
    try expect(std.mem.eql(u8, msg.value, test_msg));
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

test "read, memory failure" {
    // Fails at the end of the chain
    var f = FailingAllocator.init(t_allocator, .{ .fail_index = 3 });
    var buffer: [128]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);

    var sendreq = try init(t_allocator, "xx", "xx", "xx");
    defer sendreq.deinit(t_allocator);

    try sendreq.write(&bwriter);
    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);

    try expectError(error.OutOfMemory, read(&breader, f.allocator()));
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
