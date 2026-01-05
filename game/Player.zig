//!
//! Player, interfacing Entity
//!

const std = @import("std");

const Action = @import("roguelib").Action;
const Entity = @import("roguelib").Entity;
const Map = @import("roguelib").Map;
const MapTile = @import("roguelib").MapTile;
const Pos = @import("roguelib").Pos;
const Provider = @import("ui").Provider;
const Region = @import("roguelib").Region;
const Tileset = @import("roguelib").Tileset;

const util = @import("util.zig");

//
// Types
//

pub const Config = struct {
    provider: *Provider,
    allocator: std.mem.Allocator,
    maxx: u8,
    maxy: u8,
};

const player_vtable = Entity.VTable{
    .addMessage = playerAddMessage,
    .getAction = playerGetAction,
    .notifyDisplay = playerNotifyDisplay,
    .revealMap = playerRevealMap,
    .setKnown = playerSetKnown,
    .takeItem = playerTakeItem,
};

const Self = @This();

//
// Members
//

entity: Entity = undefined, // Must be first for vtable magic
provider: *Provider = undefined,
purse: u16 = 0,
depth: u16 = 0,

//
// Constructor
//

pub fn init(config: Config) Self {
    return .{
        .entity = Entity.config(.player, &player_vtable),
        .provider = config.provider,
    };
}

//
// Vtable methods
//

fn playerAddMessage(ptr: *Entity, msg: []const u8) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.addMessage(msg);
}

fn playerGetAction(ptr: *Entity) Action {
    const self: *Self = @ptrCast(@alignCast(ptr));
    return self.getAction();
}

fn playerNotifyDisplay(ptr: *Entity) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    return self.notifyDisplay();
}

fn playerRevealMap(ptr: *Entity, map: *Map, pos: Pos) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.revealMap(map, pos);
}

fn playerSetKnown(ptr: *Entity, map: *Map, pos: Pos, visible: bool) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.setKnown(pos, map.getTileset(pos), visible);
}

fn playerTakeItem(ptr: *Entity, i: MapTile) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.takeItem(i);
}

//
// Utility
//

fn getCommand(self: *Self) Provider.Command {
    return self.provider.getCommand();
}

fn renderRegion(self: *Self, map: *Map, r: Region, visible: bool) void {
    var _r = r; // ditch const
    var ri = _r.iterator();
    while (ri.next()) |p| {
        self.setKnown(p, map.getTileset(p), visible);
    }
}

fn setTile(self: *Self, loc: Pos, tileset: Tileset, visible: bool) void {
    self.provider.setTile(
        @intCast(loc.getX()),
        @intCast(loc.getY()),
        tileset,
        visible,
    );
}

fn getStats(self: *Self) void {
    return self.provider.getStats();
}

fn setStats(self: *Self, stats: Provider.Stats) void {
    self.provider.updateStats(stats);
}

fn incrementPurse(self: *Self) void {
    self.purse += 1;
    self.setStats(.{ .purse = self.purse, .depth = self.depth });
}

//
// Methods
//

pub fn addMessage(self: *Self, msg: []const u8) void {
    self.provider.addMessage(msg);
}

pub fn getMessage(self: *Self) []const u8 {
    return self.provider.getMessage();
}

pub fn getAction(self: *Self) Action {
    return switch (self.getCommand()) {
        .help => Action.config(.none),
        .quit => Action.config(.quit),
        .go_north => Action.configDir(.move, .north),
        .go_east => Action.configDir(.move, .east),
        .go_south => Action.configDir(.move, .south),
        .go_west => Action.configDir(.move, .west),
        .ascend => Action.config(.ascend),
        .descend => Action.config(.descend),
        .search => Action.config(.search),
        .take_item => Action.configPos(.take, self.getPos()),
        else => Action.config(.wait),
    };
}

pub fn getEntity(self: *Self) *Entity {
    return &self.entity;
}

pub fn notifyDisplay(self: *Self) void {
    self.provider.notifyDisplay();
}

pub fn resetMap(self: *Self) void {
    self.provider.resetDisplay();
}

pub fn revealMap(self: *Self, map: *Map, old_pos: Pos) void {
    self.renderRegion(
        map,
        Region.configRadius(old_pos, 1),
        false,
    );

    if (map.getRoomRegion(old_pos)) |former| {
        // Leaving a lit room : update that it is not visible
        if (map.isLit(old_pos)) {
            self.renderRegion(map, former, false);
        }
    }
    if (map.getRoomRegion(self.getPos())) |now| {
        // Entering or already in a lit room : update
        if (map.isLit(self.getPos())) {
            self.renderRegion(map, now, true);
        }
    }

    // Doorways and hallways need explicit
    self.renderRegion(
        map,
        Region.configRadius(self.getPos(), 1),
        true,
    );
}

// Map tile management

pub fn setKnown(self: *Self, loc: Pos, tileset: Tileset, visible: bool) void {
    self.setTile(loc, tileset, visible);
}

pub fn setUnknown(self: *Self, loc: Pos) void {
    const empty: Tileset = .{
        .floor = .unknown,
        .entity = .unknown,
        .item = .unknown,
    };

    self.setTile(loc, empty, false);
}

// Position

pub fn getPos(self: *Self) Pos {
    return self.entity.getPos();
}

pub fn setPos(self: *Self, p: Pos) void {
    self.entity.setPos(p);
}

// Misc

fn takeItem(self: *Self, i: MapTile) void {
    // FUTURE: no that maptile is an awful idea.  Item reference ID?
    if (i == .gold) {
        self.addMessage("You pick up the gold!");
        self.incrementPurse();
    } else { // should not happen
        self.addMessage("Nothing here to take!");
    }
}

pub fn setDepth(self: *Self, d: u16) void {
    self.depth = d;
    self.setStats(.{ .purse = self.purse, .depth = self.depth });
}

//
// Unit Tests
//

const expect = std.testing.expect;
const MockProvider = @import("ui").Mock;

test "create a player" {
    const mock_config = MockProvider.Config{
        .allocator = std.testing.allocator,
        .maxx = 10,
        .maxy = 10,
    };

    var m = try MockProvider.init(mock_config);
    defer m.deinit(std.testing.allocator);

    const config = Config{
        .provider = m.provider(),
        .allocator = std.testing.allocator,
        .maxx = 10,
        .maxy = 10,
    };

    var player = init(config);

    player.setTileKnown(Pos.config(0, 0), .floor);

    // Position identity

    const p = Pos.config(10, 10);
    player.setPos(p);
    try expect(p.eql(player.getPos()));
}

// EOF
