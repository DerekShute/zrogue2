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
stats: VisibleStats = undefined,
x: i16 = 0,
y: i16 = 0,
log: *MessageLog = undefined,

//
// Constructor and destructor
//

pub fn init(config: Config) !Self {
    var p: Self = .{
        .x = config.maxx,
        .y = config.maxy,
        .vtable = config.vtable,
        .stats = .{
            .depth = 0,
            .purse = 0,
        },
    };

    const dm = try DisplayMap.config(config.allocator, @intCast(p.x), @intCast(p.y));
    errdefer dm.deinit(config.allocator);

    const log = try MessageLog.init(config.allocator); // TODO consistency
    errdefer log.deinit();

    p.display_map = dm;
    p.log = log;

    return p;
}

pub inline fn deinit(self: Self, allocator: std.mem.Allocator) void {
    self.display_map.deinit(allocator);
    self.log.deinit();
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

pub fn setTile(self: Self, x: u16, y: u16, t: MapTile) void {
    var val = self.display_map.find(x, y) catch {
        @panic("Bad pos sent to Provider.setTile"); // THINK: error?
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
