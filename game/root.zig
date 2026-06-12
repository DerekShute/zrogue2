//!
//! The game itself as a module/object to import from the various interfaces
//!
//! Mostly a primitive original Rogue
//!

const std = @import("std");

const Map = @import("roguelib").Map;
const mapgen = @import("mapgen.zig");
pub const Player = @import("Player.zig");
const Entity = @import("roguelib").Entity;

const Self = @This();

pub const MapTile = mapgen.MapTile;

//
// Configuration
//

pub const XSIZE = mapgen.XSIZE;
pub const YSIZE = mapgen.YSIZE;

//
// Types
//

// TODO: name is key, need StringHashMapUnmanaged
pub const PlayerUID = u8; // TODO: not very U

//
// Members
//

allocator: std.mem.Allocator = undefined,
io: std.Io = undefined,

prng: std.Random.DefaultPrng = undefined,
r: std.Random = undefined,

level_config: mapgen.Config = undefined, // FUTURE: game state
map: *Map = undefined,
players: std.AutoHashMapUnmanaged(PlayerUID, Player) = undefined,
next_player_id: PlayerUID = 0,

action_queue: Entity.Queue = undefined,

// TODO: entities?, items, work queue

//
// Lifecycle
//

pub const Config = struct {
    allocator: ?std.mem.Allocator = null,
    io: ?std.Io = null,

    pub const init: @This() = .{};

    pub fn setAllocator(self: *@This(), allocator: std.mem.Allocator) void {
        self.allocator = allocator;
    }

    pub fn setIo(self: *@This(), io: std.Io) void {
        self.io = io;
    }
};

// Nonstandard but this is setting a pointer member so just easier this way
pub fn init(self: *Self, config: Config) void {
    self.level_config = .init;
    self.players = .empty;
    self.action_queue = .config();

    if (config.allocator) |a| {
        self.allocator = a;
    }

    if (config.io) |io| {
        self.io = io;
        const seed = std.Io.Timestamp.now(io, .real).toMicroseconds();
        self.prng = .init(@intCast(seed));
        self.r = self.prng.random();
    }
}

pub fn deinit(self: *Self) void {
    var it = self.players.iterator();
    while (it.next()) |kv| {
        kv.value_ptr.deinit(self.allocator);
    }

    self.players.deinit(self.allocator);

    // TODO: squash map(s);
}

//
// API
//

pub fn initPlayer(self: *Self, config: Player.Config) !PlayerUID {
    // The Player is parcel of the player map (part of the node) and is
    // owned by self.allocator

    const id = self.next_player_id;
    const gop = try self.players.getOrPut(self.allocator, self.next_player_id);
    errdefer _ = self.players.remove(id);

    if (gop.found_existing) {
        @panic("initPlayer: already that id");
    }
    const player = gop.value_ptr;

    player.* = try .init(self.allocator, config, mapgen.XSIZE, mapgen.YSIZE);
    errdefer player.deinit(self.allocator);

    self.next_player_id += 1;
    return id;
}

pub fn deinitPlayer(self: *Self, uid: PlayerUID) void {
    const p = self.players.getPtr(uid);
    if (p == null) {
        @panic("deinitPlayer: no such uid");
    }
    p.?.deinit(self.allocator);
    if (self.players.remove(uid) == false) {
        @panic("deinitPlayer: no such uid");
    }
}

pub fn getPlayer(self: *Self, uid: PlayerUID) *Player {
    const p = self.players.getPtr(uid);
    if (p == null) {
        @panic("getPlayer: no such uid");
    }
    return p.?;
}

// TODO: parcel with initPlayer?
pub fn addPlayer(self: *Self, player: *Player) void {
    level.addPlayer(self.map, player, &self.r);
    self.action_queue.enqueue(player.getEntity());
}

//
// Mapgen
//

pub fn initLevel(self: *Self) !void {
    self.map = try level.create(self.level_config, self.allocator, &self.r);
}

pub fn deinitLevel(self: *Self) void {
    self.map.deinit(self.allocator);
    self.map = undefined;
}

//
// Game Run
//

const MAX_DEPTH = 3;
const Action = @import("roguelib").Action;

const level = @import("level.zig");
const actions = @import("actions.zig");

// Simple state machine: intro -> run -> end
pub const State = enum {
    run,
    end,
};

pub fn play(self: *Self) State {
    var result: Action.Result = .continue_game;
    var state: State = .run;

    // FUTURE: Other Entities means having a .depart result

    while (self.action_queue.next()) |entity| {
        result = actions.doAction(entity, self.map) catch {
            return .end;
        };
        if (result != .continue_game) {
            break;
        }
        self.action_queue.enqueue(entity); // Continues
    }

    // TODO: this breaks single-user versus server

    switch (result) {
        .continue_game => {},
        .end_game => state = .end,
        .descend => {
            self.level_config.level += 1;
            if (self.level_config.level >= MAX_DEPTH) {
                self.level_config.going_down = false;
            }
        },
        .ascend => {
            self.level_config.level -= 1;
            if (self.level_config.level < 1) {
                state = .end;
            }
        },
    }
    return state;
}

//
// Unit tests
//

const expect = std.testing.expect;
const expectError = std.testing.expectError;
const tallocator = std.testing.allocator;
const MockClient = @import("roguelib").MockClient;
const FailingAllocator = std.testing.FailingAllocator;

test "basic use" { // If this fails then something has changed
    var f = FailingAllocator.init(tallocator, .{ .fail_index = 3 });
    var config = Config.init;
    config.setAllocator(f.allocator());

    var self: Self = undefined;
    self.init(config);
    defer self.deinit();

    var m = try MockClient.init(tallocator, 50, 50);
    defer m.deinit(tallocator);

    const id = try self.initPlayer(.{ .client = m.client() });
    defer self.deinitPlayer(id);
    const id2 = try self.initPlayer(.{ .client = m.client() });
    defer self.deinitPlayer(id2);

    _ = self.getPlayer(id);
}

test "alloc failure 0" {
    var f = FailingAllocator.init(tallocator, .{ .fail_index = 0 });
    var config = Config.init;
    config.setAllocator(f.allocator());

    var self: Self = undefined;
    self.init(config);
    defer self.deinit();

    var m = try MockClient.init(tallocator, 50, 50);
    defer m.deinit(tallocator);

    try expectError(error.OutOfMemory, self.initPlayer(.{ .client = m.client() }));
}

test "alloc failure 1" {
    var f = FailingAllocator.init(tallocator, .{ .fail_index = 1 });
    var config = Config.init;
    config.setAllocator(f.allocator());

    var self: Self = undefined;
    self.init(config);
    defer self.deinit();

    var m = try MockClient.init(tallocator, 50, 50);
    defer m.deinit(tallocator);

    try expectError(error.OutOfMemory, self.initPlayer(.{ .client = m.client() }));
}

comptime {
    _ = @import("level.zig");
    _ = @import("mapgen.zig");
    _ = @import("testing/actions.zig");
    _ = @import("testing/level.zig");
    _ = @import("testing/main.zig");
    _ = @import("testing/render.zig");
}

// EOF
