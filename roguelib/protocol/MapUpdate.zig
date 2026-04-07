//!
//! Map Update / Display Update Placeholder
//!

const std = @import("std");
const Allocator = std.mem.Allocator;
pub const MapTile = @import("../maptile.zig").MapTile;

const Self = @This();

pub const Tile = struct {
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
tile: Tile,
// TODO: slice of tiles (row update), etc.

//
// Lifecycle
//

pub fn init(allocator: Allocator, pos: []const i16, tile: Tile) !*Self {
    const s: *Self = try allocator.create(Self);
    errdefer allocator.destroy(s);
    s.x = pos[0];
    s.y = pos[1];
    s.tile = tile;
    return s;
}

pub fn deinit(self: *Self, allocator: Allocator) void {
    allocator.destroy(self);
}

pub fn valid(self: *Self) bool {
    _ = self;
    // TODO: x,y valid, etc
    return true;
}

// TODO: format

//
// Unit testing
//

const expect = std.testing.expect;
const expectError = std.testing.expectError;
const t_allocator = std.testing.allocator;
const FailingAllocator = std.testing.FailingAllocator;

test "basic usage" {
    const tile: Tile = .{
        .entity = .unknown,
        .item = .gold,
        .floor = .floor,
        .visible = true,
    };

    var msg = try init(t_allocator, &.{ 0, 1 }, tile);
    defer msg.deinit(t_allocator);
}

// EOF
