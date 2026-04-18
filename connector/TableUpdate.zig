//!
//! Table update - key value
//!
//! <table name> <table entry> <value>
//!

const std = @import("std");
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;
const Writer = std.Io.Writer;

const Self = @This();

pub const max_len = 20;

// Members

table: []const u8,
entry: []const u8,
value: []const u8,

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

pub fn read(reader: *Reader, allocator: Allocator) !*Self {
    const t_size = try reader.takeByte();
    if (t_size > max_len) {
        return error.Invalid;
    }
    const e_size = try reader.takeByte();
    if (e_size > max_len) {
        return error.Invalid;
    }
    const v_size = try reader.takeByte();
    if (v_size > max_len) {
        return error.Invalid;
    }

    const s: *Self = try allocator.create(Self);
    errdefer allocator.destroy(s);
    const t = try allocator.alloc(u8, t_size);
    errdefer allocator.free(t);
    const e = try allocator.alloc(u8, e_size);
    errdefer allocator.free(e);
    const v = try allocator.alloc(u8, v_size);
    errdefer allocator.free(v);

    try reader.readSliceAll(t);
    try reader.readSliceAll(e);
    try reader.readSliceAll(v);

    s.table = t;
    s.entry = e;
    s.value = v;

    return s;
}

pub fn write(self: *const Self, writer: *Writer) !void {
    try writer.writeByte(@truncate(self.table.len)); // implies valid size
    try writer.writeByte(@truncate(self.entry.len));
    try writer.writeByte(@truncate(self.value.len));
    try writer.writeAll(self.table);
    try writer.writeAll(self.entry);
    try writer.writeAll(self.value);
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

    var buffer: [128]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);
    try msg.write(&bwriter);

    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);

    var reply = try read(&breader, t_allocator);
    defer reply.deinit(t_allocator);

    try expect(std.mem.eql(u8, msg.table, reply.table));
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

// EOF
