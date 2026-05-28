//!
//! Player, interfacing Entity
//!

const std = @import("std");

const DisplayTile = @import("common").DisplayTile;
const MapTile = @import("common").MapTile;

const Action = @import("roguelib").Action;
const Client = @import("roguelib").Client;
const Entity = @import("roguelib").Entity;
const Map = @import("roguelib").Map;
const Pos = @import("roguelib").Pos;
const Region = @import("roguelib").Region;

//
// Types
//

pub const Config = struct {
    client: *Client,
};

const player_vtable = Entity.VTable{
    .addMessage = playerAddMessage,
    .getAction = playerGetAction,
    .setMapTile = playerSetMapTile,
    .takeItem = playerTakeItem,
};

const Self = @This();

//
// Members
//

entity: Entity = undefined, // Must be first for vtable magic
client: *Client = undefined,
purse: u16 = 0,
// FUTURE: name, connection abstraction, account information

//
// Constructor
//

pub fn init(config: Config) Self {
    const c = Entity.Config{
        .tile = .player,
        .vtable = &player_vtable,
    };

    return .{
        .entity = Entity.init(c),
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

fn playerGetAction(ptr: *Entity) !Action {
    const self: *Self = @ptrCast(@alignCast(ptr));
    return self.getAction();
}

fn playerSetMapTile(ptr: *Entity, pos: Pos, count: u8, dt: DisplayTile) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.client.setMapTile(pos, count, dt);
}

fn playerTakeItem(ptr: *Entity, i: MapTile) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.takeItem(i);
}

//
// Utility
//

fn getCommand(self: *Self) !Client.Command {
    return try self.client.getCommand();
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

pub fn getAction(self: *Self) !Action {
    const cmd = self.getCommand() catch return error.Failed;
    return switch (cmd) {
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

// Part of the larger test rig...no mock Clients here

// EOF
