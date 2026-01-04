//!
//! input/output Provider
//!
//! This module is transitional, on the way to having some Connector joining
//! engine to user interface (websocket, etc.)
//!

const std = @import("std");
const Grid = @import("roguelib").Grid;
const MapTile = @import("roguelib").MapTile;
const MessageLog = @import("MessageLog.zig");
const Tileset = @import("roguelib").Tileset;

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

pub const Stats = struct {
    depth: usize = 0,
    purse: u16 = 0,
    // TODO: strength armor etc
};

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
    notify: *const fn (ctx: *anyopaque) void,
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
x: i16 = 0,
y: i16 = 0,
log: MessageLog = undefined,
stats: Stats = .{},

//
// Constructor and destructor
//

pub fn init(config: Config) !Self {
    var p: Self = .{
        .x = config.maxx,
        .y = config.maxy,
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

// Message

pub inline fn addMessage(self: *Self, msg: []const u8) void {
    self.log.add(msg);
    self.notify();
}

pub inline fn getMessage(self: *Self) []u8 {
    // From implementation
    return self.log.get();
}

pub inline fn clearMessage(self: *Self) void {
    // From implementation
    self.log.clear();
}

pub fn notify(self: *Self) void {
    // Redraw / refresh
    self.vtable.notify(self.ptr);
}

// DisplayMapTile

pub fn getTile(self: *Self, x: u16, y: u16) DisplayMapTile {
    const tile = self.display_map.find(x, y) catch {
        @panic("Bad pos sent to Provider.getTile"); // THINK: error?
    };
    return tile.*;
}

pub fn setTile(self: *Self, x: u16, y: u16, set: Tileset, visible: bool) void {
    var val = self.display_map.find(x, y) catch {
        @panic("Bad pos sent to Provider.setTile"); // THINK: error?
    };
    val.entity = set.entity;
    val.floor = set.floor;
    val.item = set.item;
    val.visible = visible;
}

pub fn resetDisplay(self: *Self) void {
    var i = self.display_map.iterator();

    while (i.next()) |tile| {
        tile.* = .{};
    }
}

// Command

pub inline fn getCommand(self: *Self) Command {
    return self.vtable.getCommand(self.ptr);
}

// Stats

pub fn getStats(self: *Self) Stats {
    // From implementation
    return self.stats;
}

pub fn updateStats(self: *Self, stats: Stats) void {
    // TODO: this becomes a passthrough that knows nothing about stats
    // themselves : a dictionary keyed with strings or something
    self.stats = stats;
    self.notify();
}

// EOF
