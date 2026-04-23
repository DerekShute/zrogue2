//!
//! Map Update / Display Update Placeholder
//!

const std = @import("std");
pub const Tile = @import("rogueui").Tile;

const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;
const Writer = std.Io.Writer;

const Self = @This();

pos: [2]i16,
tile: Tile,
// TODO: slice of tiles (row update), etc.

//
// Lifecycle
//

pub fn init(allocator: Allocator, pos: []const i16, tile: Tile) !*Self {
    const s: *Self = try allocator.create(Self);
    errdefer allocator.destroy(s);
    s.pos[0] = pos[0];
    s.pos[1] = pos[1];
    s.tile = tile;
    return s;
}

pub fn deinit(self: *Self, allocator: Allocator) void {
    allocator.destroy(self);
}

pub fn read(reader: *Reader, allocator: Allocator) !*Self {
    const s: *Self = try allocator.create(Self);
    errdefer allocator.destroy(s);
    var buf: [2]u8 = undefined;

    try reader.readSliceAll(&buf);
    s.pos[0] = std.mem.readInt(i16, &buf, .big);
    try reader.readSliceAll(&buf);
    s.pos[1] = std.mem.readInt(i16, &buf, .big);
    s.tile.entity = try reader.takeByte();
    s.tile.item = try reader.takeByte();
    s.tile.floor = try reader.takeByte();
    const visible = try reader.takeByte();
    s.tile.visible = (visible == 1);
    return s;
}

pub fn write(self: *const Self, writer: *Writer) !void {
    var buf: [2]u8 = undefined;

    std.mem.writeInt(i16, &buf, self.pos[0], .big);
    try writer.writeAll(buf[0..]);
    std.mem.writeInt(i16, &buf, self.pos[1], .big);
    try writer.writeAll(buf[0..]);
    try writer.writeByte(self.tile.entity);
    try writer.writeByte(self.tile.item);
    try writer.writeByte(self.tile.floor);
    if (self.tile.visible) {
        try writer.writeByte(1);
    } else {
        try writer.writeByte(0);
    }
}

//
// Unit testing
//

const expect = std.testing.expect;
const expectError = std.testing.expectError;
const t_allocator = std.testing.allocator;
const FailingAllocator = std.testing.FailingAllocator;

test "basic usage" {
    const tile: Tile = .{
        .entity = 0,
        .item = 1,
        .floor = 2,
        .visible = true,
    };

    var msg = try init(t_allocator, &.{ 0, 1 }, tile);
    defer msg.deinit(t_allocator);

    var buffer: [128]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);
    try msg.write(&bwriter);

    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);

    var reply = try read(&breader, t_allocator);
    defer reply.deinit(t_allocator);

    try expect(msg.pos[0] == reply.pos[0]);
    try expect(msg.pos[1] == reply.pos[1]);
    try expect(msg.tile.entity == reply.tile.entity);
    try expect(msg.tile.item == reply.tile.item);
    try expect(msg.tile.floor == reply.tile.floor);
    try expect(msg.tile.visible == reply.tile.visible);
}

// EOF
