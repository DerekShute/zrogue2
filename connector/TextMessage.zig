//!
//! Message (from server)
//!   For now, only boring game-action related
//!
//!   message : max 80 characters
//!

const std = @import("std");
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;
const Writer = std.Io.Writer;

const Self = @This();

// Constants

pub const max_len = 80;

// Members

text: []const u8,

//
// Lifecycle
//

pub fn init(allocator: Allocator, text: []const u8) !*Self {
    const s: *Self = try allocator.create(Self);
    errdefer allocator.destroy(s);
    s.text = try allocator.dupe(u8, text);
    return s;
}

pub fn deinit(self: *Self, allocator: Allocator) void {
    allocator.free(self.text);
    allocator.destroy(self);
}

pub fn read(reader: *Reader, allocator: Allocator) !*Self {
    const size = try reader.takeByte();
    if (size > max_len) {
        return error.Invalid;
    }

    const s: *Self = try allocator.create(Self);
    errdefer allocator.destroy(s);
    const t = try allocator.alloc(u8, size);
    errdefer allocator.free(t);
    try reader.readSliceAll(t);
    s.text = t;
    return s;
}

pub fn write(self: *const Self, writer: *Writer) !void {
    try writer.writeByte(@truncate(self.text.len)); // Note implies valid size
    try writer.writeAll(self.text);
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

    var buffer: [128]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);
    try msg.write(&bwriter);

    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);

    var reply = try read(&breader, t_allocator);
    defer reply.deinit(t_allocator);

    try expect(std.mem.eql(u8, msg.text, reply.text));
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
