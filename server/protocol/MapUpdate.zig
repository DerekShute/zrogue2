//!
//! Map Update / Display Update Placeholder
//!

const std = @import("std");
const utils = @import("utils.zig");

const Reader = std.io.Reader;
const Writer = std.io.Writer;
const Allocator = std.mem.Allocator;

const Self = @This();

pub const MapTile = enum {
    unknown,
    floor,
    wall,
    trap,
    door,
    stairs_down,
    stairs_up,
    gold,
    player,
};

pub const DisplayTile = struct {
    entity: MapTile,
    item: MapTile,
    floor: MapTile,
    visible: bool,
};

//
// Members: do not supply defaults!
//

x: i16,
y: i16,
tile: DisplayTile,
// TODO: slice of tiles (row update), etc.

//
// Lifecycle
//

pub fn init(allocator: Allocator, pos: []const i16, tile: DisplayTile) !*Self {
    const s: *Self = try allocator.create(Self);
    errdefer allocator.destroy(s);
    s.x = pos[0];
    s.y = pos[1];
    s.tile = tile;
    return s;
}

pub fn copy(allocator: Allocator, basis: Self) !*Self {
    return Self.init(allocator, &.{ basis.x, basis.y }, basis.tile);
}

pub fn deinit(self: *Self, allocator: Allocator) void {
    allocator.destroy(self);
}

pub fn valid(self: *Self) bool {
    _ = self;
    // TODO: x,y valid, etc
    return true;
}

//
// Methods
//

pub const write = utils.genericWrite;

pub fn read(reader: *Reader, allocator: Allocator) !*Self {
    return utils.genericRead(Self, reader, allocator);
}

// TODO: format

//
// Unit testing
//

const expect = std.testing.expect;
const expectError = std.testing.expectError;
const t_allocator = std.testing.allocator;
const FailingAllocator = std.testing.FailingAllocator;
const msgpack = @import("msgpack");

// boring use case

test "write and read" {
    var buffer: [256]u8 = undefined;
    var bwriter = Writer.fixed(&buffer);

    const tile = DisplayTile{
        .entity = .unknown,
        .item = .gold,
        .floor = .wall,
        .visible = true,
    };

    var sendmsg = try init(t_allocator, &.{ 0, 1 }, tile);
    defer sendmsg.deinit(t_allocator);

    try expect(valid(sendmsg));

    try sendmsg.write(&bwriter);
    var breader = Reader.fixed(buffer[0..bwriter.buffered().len]);
    var msg = try read(&breader, t_allocator);
    defer msg.deinit(t_allocator);

    try expect(msg.x == sendmsg.x);
    try expect(msg.y == sendmsg.y);
    try expect(msg.tile.entity == tile.entity);
    try expect(msg.tile.item == tile.item);
    try expect(msg.tile.floor == tile.floor);
    try expect(msg.tile.visible == tile.visible);
}

// EOF
