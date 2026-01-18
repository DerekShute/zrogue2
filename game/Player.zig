//!
//! Player, interfacing Entity
//!

const std = @import("std");

const Action = @import("roguelib").Action;
const Client = @import("roguelib").Client;
const Entity = @import("roguelib").Entity;
const Map = @import("roguelib").Map;
const MapTile = @import("roguelib").MapTile;
const Pos = @import("roguelib").Pos;
const Region = @import("roguelib").Region;
const Tileset = @import("roguelib").Tileset;

const util = @import("util.zig");

//
// Types
//

pub const Config = struct {
    client: *Client,
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
client: *Client = undefined,
purse: u16 = 0,

//
// Constructor
//

pub fn init(config: Config) Self {
    return .{
        .entity = Entity.config(.player, &player_vtable),
        .client = config.client,
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

fn getCommand(self: *Self) Client.Command {
    return self.client.getCommand();
}

fn renderRegion(self: *Self, map: *Map, r: Region, visible: bool) void {
    var _r = r; // ditch const
    var ri = _r.iterator();
    while (ri.next()) |p| {
        self.setKnown(p, map.getTileset(p), visible);
    }
}

fn setTile(self: *Self, loc: Pos, tileset: Tileset, visible: bool) void {
    self.client.setTile(loc, tileset, visible);
}

fn setStatInt(self: *Self, name: []const u8, value: i32) void {
    self.client.setStatInt(name, value);
}

fn incrementPurse(self: *Self) void {
    self.purse += 1;
    self.setStatInt("purse", self.purse);
}

//
// Methods
//

pub fn addMessage(self: *Self, msg: []const u8) void {
    self.client.addMessage(msg);
}

pub fn getMessage(self: *Self) []const u8 {
    return self.client.getMessage();
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
    self.client.notifyDisplay();
}

pub fn resetMap(self: *Self) void {
    self.client.resetDisplay();
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

    self.notifyDisplay();
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

pub fn setDepth(self: *Self, depth: u16) void {
    self.setStatInt("depth", depth);
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

//
// Unit Tests
//

// See testing/ - we don't have mock clients here

// EOF
