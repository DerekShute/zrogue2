//!
//! input/output Provider, plus Mock for testing
//!
//! This module is transitional, on the way to having some Connector joining
//! engine to user interface (websocket, etc.)
//!

const std = @import("std");
const Grid = @import("roguelib").Grid;
const MessageLog = @import("roguelib").MessageLog;
const MapTile = @import("roguelib").MapTile;
const Command = @import("roguelib").Command;

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

// ===================
//
// Exported player/game stats
//

pub const VisibleStats = struct {
    depth: usize = 0,
    purse: u16 = 0,
};

// ===================
//
// Map grid as informed to us by the engine
//
// Subset of map.Place
//
pub const DisplayMapTile = struct {
    tile: MapTile,
    // TODO: monster tile, item tile
};

pub const DisplayMap = Grid(DisplayMapTile);

//
// VTable for implementation to manage
//
pub const VTable = struct {
    // input
    getCommand: *const fn (ctx: *anyopaque) Command,
};

//
// Structure Members
//
//  Hiding 'initialized' here would require back pointers from interface ctx
//  to the Provider containment

ptr: *anyopaque,
vtable: *const VTable,
display_map: DisplayMap = undefined,
stats: VisibleStats = undefined,
x: i16 = 0,
y: i16 = 0,
log: *MessageLog = undefined,

//
// Constructor and destructor
//

pub inline fn deinit(self: Self) void {
    self.display_map.deinit();
    self.log.deinit();
    self.vtable.deinit(self.ptr);
}

//
// Methods
//

pub inline fn addMessage(self: Self, msg: []const u8) void {
    self.log.add(msg);
}

pub inline fn getMessage(self: Self) []u8 {
    return self.log.get();
}

pub inline fn clearMessage(self: Self) void {
    self.log.clear();
}

pub fn setTile(self: Self, x: u16, y: u16, t: MapTile) Error!void {
    var val = self.display_map.find(x, y) catch {
        @panic("Bad pos sent to Provider.setTile"); // THINK: ignore?
    };
    val.tile = t;
}

pub fn updateStats(self: *Self, stats: VisibleStats) void {
    self.stats = stats;
}

pub inline fn getCommand(self: Self) Command {
    return self.vtable.getCommand(self.ptr);
}

// EOF
