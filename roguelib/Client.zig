//!
//! input/output Provider
//!
//! This module is transitional, on the way to having some Connector joining
//! engine to user interface (websocket, etc.)
//!

const std = @import("std");
pub const Command = @import("rogueui").Command;
pub const DisplayTile = @import("rogueui").DisplayTile;
const Grid = @import("grid.zig").Grid;
const MapTile = @import("maptile.zig").MapTile;
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
    EndOfStream,
};

// ===================
//
// Onscreen player/game stats
//

// ===================
//
// Map grid as informed to us by the engine
//
// TODO: probably better to capture 'needs update' and work backwards
pub const DisplayMap = Grid(DisplayTile);

//
// VTable for implementation to manage
//
pub const VTable = struct {
    addMessage: *const fn (ctx: *anyopaque, msg: []const u8) void,
    // input
    getCommand: *const fn (ctx: *anyopaque) Error!Command,

    // "Thing has changed" updates to send to implementation
    notifyDisplay: *const fn (ctx: *anyopaque) void,

    // Update a map location with new information
    setMapTile: *const fn (ctx: *anyopaque, u: u16, u: u16, tile: DisplayTile) void,

    // Stats known by game and provider implementation
    setStatInt: *const fn (ctx: *anyopaque, name: []const u8, value: i32) void,
};

//
// Config
//

pub const Config = struct {
    allocator: std.mem.Allocator,
    xsize: i16,
    ysize: i16,
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

// min/max of display map delta
min_delta: Pos = undefined,
max_delta: Pos = undefined,

//
// Constructor and destructor
//

pub fn init(config: Config) !Self {
    var p: Self = .{
        .x = config.xsize,
        .y = config.ysize,
        .min_delta = Pos.config(0, 0),
        .max_delta = Pos.config(0, 0),
        .vtable = config.vtable,
    };

    const dm = try DisplayMap.config(config.allocator, @intCast(p.x), @intCast(p.y));
    errdefer dm.deinit(config.allocator);

    p.display_map = dm;
    p.resetDisplay();

    return p;
}

pub inline fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.display_map.deinit(allocator);
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
    self.vtable.addMessage(self.ptr, msg);
}

pub fn notifyDisplay(self: *Self) void {
    // Redraw / refresh
    self.vtable.notifyDisplay(self.ptr);
}

pub fn setMapTile(self: *Self, pos: Pos, tile: Tileset, visible: bool) void {
    const dt = DisplayTile{
        .entity = tile.entity,
        .floor = tile.floor,
        .item = tile.item,
        .visible = visible,
    };

    self.vtable.setMapTile(
        self.ptr,
        @intCast(pos.getX()),
        @intCast(pos.getY()),
        dt,
    );
}

// DisplayTile

pub fn getTile(self: *Self, p: Pos) DisplayTile {
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
    val.entity = @intFromEnum(set.entity); // TODO: until all consolidated
    val.floor = @intFromEnum(set.floor);
    val.item = @intFromEnum(set.item);
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
        tile.* = .init;
    }
    self.needRefresh();
}

// Command

pub inline fn getCommand(self: *Self) Error!Command {
    return try self.vtable.getCommand(self.ptr);
}

// Stats

pub fn setStatInt(self: *Self, name: []const u8, value: i32) void {
    self.vtable.setStatInt(self.ptr, name, value);
}

//
// Unit tests
//

// See testing/MockProvider.zig

//
// Visualization
//

const genFields = @import("utils/visual.zig").genFields;
pub var fields = genFields(Self);
pub var displaytile_fields = genFields(DisplayTile);

// EOF
