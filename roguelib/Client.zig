//!
//! input/output Provider
//!
//! This module is transitional, on the way to having some Connector joining
//! engine to user interface (websocket, etc.)
//!

const std = @import("std");
pub const Command = @import("rogueui").Command;
pub const DisplayTile = @import("rogueui").DisplayTile;
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

//
// VTable for implementation to manage
//
pub const VTable = struct {
    addMessage: *const fn (ctx: *anyopaque, msg: []const u8) void,
    // input
    getCommand: *const fn (ctx: *anyopaque) Error!Command,

    // Update a map location with new information
    setMapTile: *const fn (ctx: *anyopaque, u: u16, u: u16, tile: DisplayTile) void,

    // Stats known by game and provider implementation
    setStatInt: *const fn (ctx: *anyopaque, name: []const u8, value: i32) void,
};

//
// Structure Members
//
//  Hiding 'initialized' here would require back pointers from interface ctx
//  to the Provider containment

ptr: *anyopaque = undefined,
vtable: *const VTable,

//
// Lifecycle
//

pub const Config = struct {
    vtable: *const VTable,
};

pub fn init(config: Config) !Self {
    const p: Self = .{
        .vtable = config.vtable,
    };

    // TODO: caller manages p.ptr and that is suboptimal

    return p;
}

pub inline fn deinit(self: *Self) void {
    _ = self;
}

//
// Methods
//

// Message

pub inline fn addMessage(self: *Self, msg: []const u8) void {
    self.vtable.addMessage(self.ptr, msg);
}

pub fn setMapTile(self: *Self, pos: Pos, tile: Tileset, visible: bool) void {
    const dt = DisplayTile{
        .entity = @intFromEnum(tile.entity),
        .floor = @intFromEnum(tile.floor),
        .item = @intFromEnum(tile.item),
        .visible = visible,
    };

    self.vtable.setMapTile(
        self.ptr,
        @intCast(pos.getX()),
        @intCast(pos.getY()),
        dt,
    );
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
pub var displaytile_fields = genFields(DisplayTile); // Harmless lie

// EOF
