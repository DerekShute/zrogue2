//!
//! Test/game state encapsulation
//!

const std = @import("std");
const Action = @import("roguelib").Action;
const Client = @import("roguelib").Client;
const Map = @import("roguelib").Map;
const MapTile = @import("roguelib").MapTile;
const MockClient = @import("roguelib").MockClient;
const Pos = @import("roguelib").Pos;

const game = @import("../root.zig");

const level = @import("level.zig"); // Test level

const expect = std.testing.expect;
const Self = @This();

client: *MockClient,
map: *Map,
player: *game.Player,

//
// Lifecycle
//

pub fn init(allocator: std.mem.Allocator) !*Self {
    var mc = try allocator.create(MockClient);
    errdefer allocator.destroy(mc);
    mc.* = try MockClient.init();

    var player = try allocator.create(game.Player);
    errdefer allocator.destroy(player);
    player.* = game.Player.init(.{ .client = mc.client() });

    const map = try level.create(allocator, player.getEntity());
    errdefer allocator.destroy(map);

    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);

    self.* = .{
        .client = mc,
        .map = map,
        .player = player,
    };
    return self;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.map.deinit(allocator);
    allocator.destroy(self.player);
    allocator.destroy(self.client);
    allocator.destroy(self);
}

//
// Methods
//

pub fn expectFloor(self: *Self, pos: Pos, floor: MapTile) !void {
    try expect(self.map.getFloorTile(pos) == floor);
}

pub fn expectItem(self: *Self, item: MapTile) !void {
    try expect(self.map.getItem(self.player.getPos()) == item);
}

pub fn expectMessage(self: *Self, msg: []const u8) !void {
    try expect(std.mem.eql(u8, self.client.getMessage(), msg));
}

pub fn expectPurse(self: *Self, val: i16) !void {
    try expect(self.client.getStatPurse() == val);
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
