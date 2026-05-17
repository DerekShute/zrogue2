//!
//! Test/game state encapsulation
//!

const std = @import("std");
const Action = @import("roguelib").Action;
const Client = @import("roguelib").Client;
const FOVMap = @import("roguelib").FOVMap;
const Map = @import("roguelib").Map;
const MapTile = @import("roguelib").MapTile;
const MockClient = @import("roguelib").MockClient;
const Pos = @import("roguelib").Pos;

const game = @import("../root.zig");

const fov = @import("../fov.zig");
const level = @import("level.zig"); // Test level

const expect = std.testing.expect;
const Self = @This();

client: *MockClient,
map: *Map,
player: *game.Player,
f: *FOVMap,

//
// Lifecycle
//

pub fn init(allocator: std.mem.Allocator) !*Self {
    var mc = try allocator.create(MockClient);
    errdefer allocator.destroy(mc);
    mc.* = try MockClient.init(allocator, game.XSIZE, game.YSIZE);
    errdefer mc.deinit(allocator);

    var player = try allocator.create(game.Player);
    errdefer allocator.destroy(player);
    player.* = game.Player.init(.{ .client = mc.client() });

    const entity = player.getEntity();
    var f = try allocator.create(FOVMap);
    errdefer allocator.destroy(f);
    f.* = try FOVMap.init(allocator, game.XSIZE, game.YSIZE);
    errdefer f.deinit(allocator);
    entity.setFOV(f);

    const map = try level.create(allocator, entity);
    errdefer allocator.destroy(map);

    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);

    self.* = .{
        .client = mc,
        .f = f,
        .map = map,
        .player = player,
    };

    fov.revealMap(entity, map, player.getPos());
    entity.notifyDisplay(map);

    return self;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.map.deinit(allocator);
    allocator.destroy(self.player);
    self.f.deinit(allocator);
    allocator.destroy(self.f);
    self.client.deinit(allocator);
    allocator.destroy(self.client);
    allocator.destroy(self);
}

//
// Methods
//

pub fn getEntity(self: *Self, x: i16, y: i16) MapTile {
    const dt = self.client.getTile(x, y) catch @panic("getEntity fault");
    return @enumFromInt(dt.entity);
}

pub fn moveTo(self: *Self, pos: Pos) void {
    const orig = self.player.getPos();
    const entity = self.player.getEntity();
    self.map.removeEntity(orig);
    self.player.setPos(pos);
    self.map.addEntity(entity, pos);
    fov.revealMap(entity, self.map, orig);
    entity.notifyDisplay(self.map);
}

pub fn expectFloor(self: *Self, pos: Pos, floor: MapTile) !void {
    // NOCOMMIT this doesn't test for visibility
    try expect(self.map.getFloorTile(pos) == floor);
}

pub fn expectItemAtPlayer(self: *Self, item: MapTile) !void {
    try expect(self.map.getItem(self.player.getPos()) == item);
}

pub fn expectItem(self: *Self, pos: Pos, item: MapTile) !void {
    try expect(self.map.getItem(pos) == item);
}

pub fn expectMessage(self: *Self, msg: []const u8) !void {
    try expect(std.mem.eql(u8, self.client.getMessage(), msg));
}

pub fn expectPurse(self: *Self, val: i16) !void {
    try expect(self.client.getStatPurse() == val);
}

pub fn expectNotVisible(self: *Self, x: Pos.Dim, y: Pos.Dim) !void {
    const dt = try self.client.getTile(x, y);
    try expect(!dt.visible);
}

pub fn expectVisible(self: *Self, x: Pos.Dim, y: Pos.Dim) !void {
    const dt = try self.client.getTile(x, y);
    try expect(dt.visible);
}

pub fn revealMap(self: *Self) void {
    fov.revealMap(self.player.getEntity(), self.map, self.player.getPos());
}

pub fn step(self: *Self, cmd: Client.Command) !Action.Result {
    self.client.setCommand(cmd);
    return try game.doAction(self.player.getEntity(), self.map);
}

pub fn atXY(self: *Self, x: Pos.Dim, y: Pos.Dim) !void {
    try expect(self.player.getPos().getX() == x);
    try expect(self.player.getPos().getY() == y);
}

// EOF
