//!
//! Test/game state encapsulation
//!

const std = @import("std");
const Action = @import("roguelib").Action;
const Client = @import("roguelib").Client;
const FOVMap = @import("roguelib").FOVMap;
const Map = @import("roguelib").Map;
const MockClient = @import("roguelib").MockClient;
const Player = @import("../Player.zig");
const Pos = @import("roguelib").Pos;
const Tile = @import("common").Tile;

const actions = @import("../actions.zig");
const level = @import("level.zig"); // Test level
const mapgen = @import("../mapgen.zig");
const MapTile = mapgen.MapTile;

const expect = std.testing.expect;
const Self = @This();

client: *MockClient,
map: *Map,
player: *Player,

//
// Lifecycle
//

pub fn init(allocator: std.mem.Allocator) !*Self {
    var mc = try allocator.create(MockClient);
    errdefer allocator.destroy(mc);
    mc.* = try MockClient.init(allocator, mapgen.XSIZE, mapgen.YSIZE);
    errdefer mc.deinit(allocator);

    // REFACTOR: use Game with its conveniences

    var player = try allocator.create(Player);
    errdefer allocator.destroy(player);
    player.* = try Player.init(
        allocator,
        .{ .client = mc.client() },
        mapgen.XSIZE,
        mapgen.YSIZE,
    );
    errdefer player.deinit(allocator);

    // REFACTOR: fix level.create to act more naturally
    const map = try level.create(allocator, player.getEntity());
    errdefer allocator.destroy(map);

    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);

    self.* = .{
        .client = mc,
        .map = map,
        .player = player,
    };

    actions.move(player, map, player.getPos());
    player.notifyDisplay(map);

    return self;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.map.deinit(allocator);
    self.player.deinit(allocator);
    allocator.destroy(self.player);
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
    _ = self.client.getMapUpdates();
    _ = self.client.getTileUpdates();
    actions.move(self.player, self.map, pos);
    self.player.notifyDisplay(self.map);
}

pub fn expectFloor(self: *Self, pos: Pos, floor: MapTile) !void {
    try expect(mapgen.getFloor(self.map, pos) == floor);
}

pub fn expectItemAtPlayer(self: *Self, item: MapTile) !void {
    const t: Tile = @enumFromInt(@intFromEnum(item));
    try expect(self.map.getItem(self.player.getPos()) == t);
}

pub fn expectItem(self: *Self, pos: Pos, item: MapTile) !void {
    const t: Tile = @enumFromInt(@intFromEnum(item));
    try expect(self.map.getItem(pos) == t);
}

pub fn expectMapUpdates(self: *Self, count: i32) !void {
    const got = self.client.getMapUpdates();
    try expect(got == count);
}

pub fn expectTileUpdates(self: *Self, count: i32) !void {
    const got = self.client.getTileUpdates();
    try expect(got == count);
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

pub fn step(self: *Self, cmd: Client.Command) !Action.Result {
    self.client.setCommand(cmd);
    return try actions.doAction(self.player.getEntity(), self.map);
}

pub fn atXY(self: *Self, x: Pos.Dim, y: Pos.Dim) !void {
    try expect(self.player.getPos().getX() == x);
    try expect(self.player.getPos().getY() == y);
}

// EOF
