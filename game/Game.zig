//!
//! Game container
//!
const std = @import("std");

const Map = @import("roguelib").Map;
const mapgen = @import("mapgen.zig");
const Player = @import("Player.zig");
const Entity = @import("roguelib").Entity;

const Self = @This();

//
// Types
//

// TODO: name is key, need StringHashMapUnmanaged
pub const PlayerUID = u8; // TODO: not very U

//
// Members
//

allocator: std.mem.Allocator = undefined,
r: *std.Random = undefined,
level_config: mapgen.Config = undefined, // FUTURE: game state
map: *Map = undefined,
players: std.AutoHashMapUnmanaged(PlayerUID, Player) = undefined,
next_player_id: PlayerUID = 0,

// TODO: entities?, items, work queue

//
// Lifecycle
//

pub const Config = struct {
    allocator: ?std.mem.Allocator = null,
    r: ?*std.Random = null,

    pub const init: @This() = .{};

    pub fn setAllocator(self: *@This(), allocator: std.mem.Allocator) void {
        self.allocator = allocator;
    }

    pub fn setRandom(self: *@This(), r: *std.Random) void {
        self.r = r;
    }
};

pub fn init(config: Config) Self {
    var s: Self = .{
        .level_config = .init,
        .players = .empty,
    };

    if (config.allocator) |a| {
        s.allocator = a;
    }

    if (config.r) |r| {
        s.r = r;
    }

    return s;
}

pub fn deinit(self: *Self) void {
    // TODO: walk players and deinit.  This is currently only a client thing
    // and is scoped elsewhere

    self.players.deinit(self.allocator);

    // TODO: squash map(s);
}

//
// API
//

pub fn initPlayer(self: *Self, config: Player.Config) !PlayerUID {
    // The Player is parcel of the player map (part of the node)

    const id = self.next_player_id;
    try self.players.put(self.allocator, self.next_player_id, .init(config));
    self.next_player_id += 1;
    return id;
}

pub fn deinitPlayer(self: *Self, uid: PlayerUID) void {
    if (self.players.remove(uid) == false) {
        @panic("deinitPlayer: no such uid");
    }
}

pub fn getPlayer(self: *Self, uid: PlayerUID) Player {
    const p = self.players.get(uid);
    if (p == null) {
        @panic("getPlayer: no such uid");
    }
    return p.?;
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
    var f = FailingAllocator.init(tallocator, .{ .fail_index = 1 });
    var config = Config.init;
    config.setAllocator(f.allocator());

    var self = init(config);
    defer self.deinit();

    var m = try MockClient.init(tallocator, 50, 50);
    defer m.deinit(tallocator);

    const id = try self.initPlayer(.{ .client = m.client() });
    _ = try self.initPlayer(.{ .client = m.client() });

    _ = self.getPlayer(id);

    self.deinitPlayer(id);
}

test "alloc failure 0" {
    var f = FailingAllocator.init(tallocator, .{ .fail_index = 0 });
    var config = Config.init;
    config.setAllocator(f.allocator());

    var self = init(config);
    defer self.deinit();

    var m = try MockClient.init(tallocator, 50, 50);
    defer m.deinit(tallocator);

    try expectError(error.OutOfMemory, self.initPlayer(.{ .client = m.client() }));
}

// EOF
