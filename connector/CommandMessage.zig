//!
//! Commands from connected client/player to server
//!

const std = @import("std");
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;
const Writer = std.Io.Writer;

const Self = @This();

// Members

c: u16,

//
// Lifecycle
//

pub fn init(allocator: Allocator, cmd: u16) !*Self {
    const s: *Self = try allocator.create(Self);
    errdefer allocator.destroy(s);
    s.c = cmd;
    return s;
}

pub fn deinit(self: *Self, allocator: Allocator) void {
    allocator.destroy(self);
}

pub fn read(reader: *Reader, allocator: Allocator) !*Self {
    var buf: [2]u8 = undefined;
    try reader.readSliceAll(&buf);
    const cmd = std.mem.readInt(u16, &buf, .big);
    const s: *Self = try init(allocator, cmd);
    errdefer s.deinit(allocator);
    return s;
}

pub fn write(self: *const Self, writer: *Writer) !void {
    var buf: [2]u8 = undefined;
    std.mem.writeInt(u16, &buf, self.c, .big);
    try writer.writeAll(buf[0..]);
}

//
// Unit testing
//

const expect = std.testing.expect;
const expectError = std.testing.expectError;
const t_allocator = std.testing.allocator;
const FailingAllocator = std.testing.FailingAllocator;

test "basic usage" {
    var msg = try init(t_allocator, 100);
    defer msg.deinit(t_allocator);

    var buffer: [128]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);
    try msg.write(&bwriter);

    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);

    var reply = try read(&breader, t_allocator);
    defer reply.deinit(t_allocator);

    try expect(msg.c == reply.c);
}

test "memory failure" {
    var f = FailingAllocator.init(t_allocator, .{ .fail_index = 0 });
    try expectError(error.OutOfMemory, init(f.allocator(), 100));
}

// EOF
