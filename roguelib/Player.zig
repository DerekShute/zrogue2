//!
//! Player, interfacing Entity
//!

const std = @import("std");

const Action = @import("Action.zig");
const Client = @import("Client.zig");
const Entity = @import("Entity.zig");
const Map = @import("Map.zig");
const MapTile = @import("maptile.zig").MapTile;
const Pos = @import("Pos.zig");
const Region = @import("Region.zig");
const Tileset = @import("maptile.zig").Tileset;

//
// Types
//

pub const Config = struct {
    client: *Client,
};

const player_vtable = Entity.VTable{
    .addMessage = playerAddMessage,
    .getAction = playerGetAction,
    .revealMap = playerRevealMap,
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

fn playerRevealMap(ptr: *Entity, map: *Map, pos: Pos) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.revealMap(map, pos);
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

fn renderRegion(self: *Self, r: Region, visible: bool) void {
    var _r = r; // ditch const
    var ri = _r.iterator();
    while (ri.next()) |p| {
        self.entity.setPosVisible(p, visible);
    }
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

//
// It's up to the client and end UI to decide what to do with map areas that
// are no longer visible.  It could remove them from the display, or dim them,
// or only retain known-persistent features
//
pub fn notifyDisplay(self: *Self, map: *Map) void {
    // FUTURE: consolidate identical tiles, have a count
    if (self.entity.fov) |fov| { // NOCOMMIT: demeter
        var i = fov.iterator();
        while (i.next_changed()) |change| {
            var tile = Tileset.init; // unknown, not visible
            if (change.visible) {
                tile = map.getTileset(change.pos);
            }
            self.client.setMapTile(change.pos, tile, change.visible);
        }
    }
    // TODO: setMapflush or something
}

// NOCOMMIT: How is this used?
pub fn resetMap(self: *Self) void {
    self.client.resetDisplay();
}

// NOCOMMIT: game movement and place-on-map logic.  This can be relocated to
// the game code entirely!
pub fn revealMap(self: *Self, map: *Map, old_pos: Pos) void {
    // FUTURE: this is game / Rogue specific

    // Border-of-room and in-corridor hack
    self.renderRegion(.configRadius(old_pos, 1), false);

    // TODO: only if former != now
    if (map.getRoomRegion(old_pos)) |former| {
        // Leaving a lit room : update that it is not visible
        if (map.isLit(old_pos)) {
            self.renderRegion(former, false);
        }
    }
    if (map.getRoomRegion(self.getPos())) |now| {
        // Entering or already in a lit room : update
        if (map.isLit(self.getPos())) {
            self.renderRegion(now, true);
        }
    }

    // Doorways and hallways need explicit
    self.renderRegion(.configRadius(self.getPos(), 1), true);

    self.notifyDisplay(map);
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

//
// Visualization
//

const genFields = @import("utils/visual.zig").genFields;
pub var fields = genFields(Self);

// EOF
