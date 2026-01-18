//!
//! input/output Provider
//!
//! This module is transitional, on the way to having some Connector joining
//! engine to user interface (websocket, etc.)
//!

const std = @import("std");
const Grid = @import("grid.zig").Grid;
const MapTile = @import("maptile.zig").MapTile;
const MessageLog = @import("client/MessageLog.zig");
const Pos = @import("Pos.zig");
const Tileset = @import("maptile.zig").Tileset;

const Self = @This();

//
// Errors that can come out of this or of any implementation
//
pub const Error = error{
    NotInitialized,
    AlreadyInitialized,
    ProviderError,
    DisplayTooSmall, // Curses
    OutOfMemory,
};

//
// Input abstraction
//

pub const Command = enum {
    wait,
    quit,
    go_north, // 'up'/'down' confusing w/r/t stairs
    go_east,
    go_south,
    go_west,
    ascend,
    descend,
    help,
    take_item,
    search,
};

// ===================
//
// Onscreen player/game stats
//

// ===================
//
// Map grid as informed to us by the engine
//
// Subset of map.Place
//
pub const DisplayMapTile = struct {
    entity: MapTile = .unknown,
    item: MapTile = .unknown,
    floor: MapTile = .unknown,
    visible: bool = false,
};

pub const DisplayMap = Grid(DisplayMapTile);

//
// VTable for implementation to manage
//
pub const VTable = struct {
    // input
    getCommand: *const fn (ctx: *anyopaque) Command,

    // "Thing has changed" updates to send to implementation
    notifyDisplay: *const fn (ctx: *anyopaque) void,

    // Stats known by game and provider implementation
    setStatInt: *const fn (ctx: *anyopaque, name: []const u8, value: i32) void,
};

//
// Config
//

pub const Config = struct {
    allocator: std.mem.Allocator,
    maxx: u8,
    maxy: u8,
    vtable: *const VTable,
};

//
// Structure Members
//
//  Hiding 'initialized' here would require back pointers from interface ctx
//  to the Provider containment

ptr: *anyopaque = undefined,
vtable: *const VTable,
display_map: DisplayMap = undefined,
x: Pos.Dim = 0, // size, so index [0..x-1]
y: Pos.Dim = 0, // size, so index [0..y-1]
log: MessageLog = undefined,

// min/max of display map delta
min_delta: Pos = undefined,
max_delta: Pos = undefined,

//
// Constructor and destructor
//

pub fn init(config: Config) !Self {
    var p: Self = .{
        .x = config.maxx,
        .y = config.maxy,
        .min_delta = Pos.config(0, 0),
        .max_delta = Pos.config(0, 0),
        .vtable = config.vtable,
        .log = MessageLog.init(),
    };

    const dm = try DisplayMap.config(config.allocator, @intCast(p.x), @intCast(p.y));
    errdefer dm.deinit(config.allocator);

    p.display_map = dm;
    p.resetDisplay();

    return p;
}

pub inline fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.display_map.deinit(allocator);
    // Log has no deinit
}

//
// Methods
//

// DisplayMap iterator

pub fn displayChange(self: *Self) ?Pos.Range {
    if (self.max_delta.getX() == -1) { // Nothing changed
        return null;
    }
    const pr = Pos.Range.init(self.min_delta, self.max_delta);

    // Reset to 'no update needed': we are iterating through now

    self.min_delta = Pos.config(self.x + 1, self.y + 1);
    self.max_delta = Pos.config(-1, -1);

    return pr;
}

// Message

pub inline fn addMessage(self: *Self, msg: []const u8) void {
    self.log.add(msg);
    self.notifyDisplay();
}

pub inline fn getMessage(self: *Self) []u8 {
    // From implementation
    return self.log.get();
}

pub inline fn clearMessage(self: *Self) void {
    // From implementation
    self.log.clear();
}

pub fn notifyDisplay(self: *Self) void {
    // Redraw / refresh
    self.vtable.notifyDisplay(self.ptr);
}

// DisplayMapTile

pub fn getTile(self: *Self, p: Pos) DisplayMapTile {
    const tile = self.display_map.find(
        @intCast(p.getX()),
        @intCast(p.getY()),
    ) catch {
        @panic("Bad pos sent to Provider.getTile"); // THINK: error?
    };
    return tile.*;
}

pub fn setTile(self: *Self, p: Pos, set: Tileset, visible: bool) void {
    var val = self.display_map.find(
        @intCast(p.getX()),
        @intCast(p.getY()),
    ) catch {
        @panic("Bad pos sent to Provider.setTile"); // THINK: error?
    };
    val.entity = set.entity;
    val.floor = set.floor;
    val.item = set.item;
    val.visible = visible;

    // Grow the needing-update window if necessary
    self.min_delta = Pos.config(
        @min(p.getX(), self.min_delta.getX()),
        @min(p.getY(), self.min_delta.getY()),
    );
    self.max_delta = Pos.config(
        @max(p.getX(), self.max_delta.getX()),
        @max(p.getY(), self.max_delta.getY()),
    );
}

pub fn needRefresh(self: *Self) void {
    // Mark the entire display as needing update
    self.min_delta = Pos.config(0, 0);
    self.max_delta = Pos.config(self.x - 1, self.y - 1);
}

pub fn resetDisplay(self: *Self) void {
    var i = self.display_map.iterator();
    while (i.next()) |tile| {
        tile.* = .{};
    }
    self.needRefresh();
}

// Command

pub inline fn getCommand(self: *Self) Command {
    return self.vtable.getCommand(self.ptr);
}

// Stats

pub fn setStatInt(self: *Self, name: []const u8, value: i32) void {
    self.vtable.setStatInt(self.ptr, name, value);
}

//
// Unit tests
//

// See testing/MockProvider.zig

// EOF
