//!
//! Player, interfacing Entity
//!

const std = @import("std");

const DisplayTile = @import("common").DisplayTile;

const Action = @import("roguelib").Action;
const Client = @import("roguelib").Client;
const Entity = @import("roguelib").Entity;
const FOVMap = @import("roguelib").FOVMap;
const Map = @import("roguelib").Map;
const Pos = @import("roguelib").Pos;
const Region = @import("roguelib").Region;

const actions = @import("actions.zig");
const mapgen = @import("mapgen.zig");
const MapTile = mapgen.MapTile;

const Allocator = std.mem.Allocator;

//
// Types
//

pub const Config = struct {
    client: *Client,
};

const player_vtable = Entity.VTable{
    .doAction = actions.doAction,
};

const Self = @This();

//
// Members
//

entity: Entity = undefined, // Must be first for vtable magic
client: *Client = undefined,
fov: FOVMap = undefined,

purse: u16 = 0,
// FUTURE: name, connection abstraction, account information

//
// Lifecycle
//

pub fn init(allocator: Allocator, config: Config, width: usize, height: usize) !Self {
    const c = Entity.Config{
        .tile = .fromOther(MapTile.player),
        .vtable = &player_vtable,
    };

    return .{
        .entity = Entity.init(c),
        .client = config.client,
        .fov = try .init(allocator, width, height),
    };
}

pub fn deinit(self: *Self, allocator: Allocator) void {
    self.fov.deinit(allocator);
}

pub fn getFOV(self: *Self) *FOVMap {
    return &self.fov;
}

pub fn resetFOV(self: *Self) void {
    self.fov.reset();
}

//
// Vtable methods
//

fn playerGetAction(ptr: *Entity) !Action {
    const self: *Self = @ptrCast(@alignCast(ptr));
    return self.getAction();
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

pub fn incrementPurse(self: *Self) void {
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

fn setMapTile(self: *Self, pos: Pos, count: u8, dt: DisplayTile) void {
    self.client.setMapTile(pos, count, dt);
}

// Position

pub fn getPos(self: *Self) Pos {
    return self.entity.getPos();
}

pub fn setPos(self: *Self, p: Pos) void {
    self.setPosChanged(self.getPos());
    self.entity.setPos(p);
    self.setPosChanged(p);
}

pub fn setDepth(self: *Self, depth: u16) void {
    self.setStatInt("depth", depth);
}

//
// Field of Vision
//

// It's up to the client and end UI to decide what to do with map areas that
// are no longer visible.  It could remove them from the display, or dim them,
// or only retain known-persistent features.
//
// This could be done piecemeal but that reduces opportunity for consolidation
//
// TODO: still not really cool with this
// FUTURE: slice of DisplayTile
//
pub fn notifyDisplay(self: *Self, map: *Map) void {
    var dt: DisplayTile = undefined;
    var pos: Pos = undefined;
    var count: u8 = 0;

    var i = self.fov.iterator();
    while (i.next_changed()) |change| {
        if (count == 0) {
            pos = change.pos;
            count = 1;
            dt = .init;
            if (change.visible) {
                const tile = map.getTileset(change.pos);
                dt = DisplayTile{
                    .entity = @intFromEnum(tile.entity),
                    .floor = @intFromEnum(tile.floor),
                    .item = @intFromEnum(tile.item),
                    .visible = true,
                };
            }
            continue;
        }
        // One in the tank; can it be combined?

        const tile = map.getTileset(change.pos);
        if ((change.pos.getY() == pos.getY()) and
            (change.pos.getX() == pos.getX() + count))
        {
            if (!change.visible and !dt.visible) {
                // Equally invisible; can combine
                count = count + 1;
                continue;
            }

            if ((change.visible == dt.visible) and // implies both visible
                (dt.entity == @intFromEnum(tile.entity)) and
                (dt.floor == @intFromEnum(tile.floor)) and
                (dt.item == @intFromEnum(tile.item)))
            {
                // The same and both visible; combine
                count = count + 1;
                continue;
            }
        }

        // Can't graft it, so flush the existing and keep going
        self.setMapTile(pos, count, dt);
        pos = change.pos;
        count = 1;
        dt = .init;
        if (change.visible) {
            dt = DisplayTile{
                .entity = @intFromEnum(tile.entity),
                .floor = @intFromEnum(tile.floor),
                .item = @intFromEnum(tile.item),
                .visible = true,
            };
        }
    } // While
    if (count > 0) {
        // Flush anything trailing
        self.setMapTile(pos, count, dt);
    }
}

pub fn setPosChanged(self: *Self, loc: Pos) void {
    if (loc.getX() != -1) {
        self.fov.setChanged(loc, true);
    }
}

pub fn setRegionVisible(self: *Self, region: Region, visible: bool) void {
    var _r = region; // Flip to var
    var ri = _r.iterator();
    while (ri.next()) |p| {
        self.fov.setVisible(p, visible);
    }
}

// Misc

pub fn takeItem(self: *Self, map: *Map, pos: Pos) void {
    if (mapgen.getItem(map, pos) == .gold) {
        self.addMessage("You pick up the gold!");
        self.incrementPurse();
        mapgen.addItem(map, pos, .unknown);
    } else { // should not happen
        self.addMessage("Nothing here to take!");
    }
}

//
// Unit Tests
//

// Part of the larger test rig...no mock Clients here

// EOF
