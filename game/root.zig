//!
//! The game itself as a module/object to import from the various interfaces
//!
//! Mostly a primitive original Rogue
//!

const std = @import("std");

const Entity = @import("roguelib").Entity;
const EventQueue = @import("roguelib").EventQueue;
const Map = @import("roguelib").Map;
const mapgen = @import("mapgen.zig");
pub const Player = @import("Player.zig");

const World = @import("roguelib").World;

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

world: World = undefined, // MUST BE FIRST

allocator: std.mem.Allocator = undefined,
arena: std.heap.ArenaAllocator = undefined,

level_config: mapgen.Config = undefined, // FUTURE: game state
players: std.AutoHashMapUnmanaged(PlayerUID, Player) = undefined,
next_player_id: PlayerUID = 0,

//
// Lifecycle
//

pub const init: Self = .{
    .level_config = .init,
    .players = .empty,
    .world = .init,
};

// Builder pattern

pub fn configAllocator(self: *Self, allocator: std.mem.Allocator) void {
    self.allocator = allocator;

    // World gets sandboxed into an arena allocator
    self.arena = .init(allocator);
    self.world.configAllocator(self.arena.allocator());
}

pub fn configIo(self: *Self, io: std.Io) void {
    self.world.configIo(io);
}

pub fn configRandom(self: *Self, random: std.Random) void {
    self.world.configRandom(random);
}

pub fn deinit(self: *Self) void {
    const allocator = self.allocator;

    var it = self.players.iterator();
    while (it.next()) |kv| {
        kv.value_ptr.deinit(allocator);
    }

    self.players.deinit(allocator);

    // TODO: event queue cleanup

    // TODO: squash map(s);

    self.arena.deinit();
}

//
// API
//

pub fn initPlayer(self: *Self, config: Player.Config) !PlayerUID {
    // The Player is parcel of the player map (part of the node) and is
    // owned by the Game, not the World
    const allocator = self.allocator;

    const id = self.next_player_id;
    const gop = try self.players.getOrPut(allocator, self.next_player_id);
    errdefer _ = self.players.remove(id);

    if (gop.found_existing) {
        @panic("initPlayer: already that id");
    }
    const player = gop.value_ptr;

    player.* = try .init(allocator, config, mapgen.XSIZE, mapgen.YSIZE);
    errdefer player.deinit(allocator);

    self.next_player_id += 1;
    return id;
}

pub fn deinitPlayer(self: *Self, uid: PlayerUID) void {
    const allocator = self.allocator;
    const p = self.players.getPtr(uid);
    if (p == null) {
        @panic("deinitPlayer: no such uid");
    }
    p.?.deinit(allocator);
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

fn enqueueEntity(self: *Self, entity: *Entity) void {
    self.world.enqueueEvent(EventQueue.Event{ .entity = entity });
}

// TODO: parcel with initPlayer?
pub fn addPlayer(self: *Self, player: *Player) void {
    level.addPlayer(self.world.map, player, &self.world);
    self.enqueueEntity(player.getEntity());
}

//
// Mapgen
//

pub fn setLevel(self: *Self, lvl: u16) void {
    self.level_config.level = lvl;
}

pub fn setGoingDown(self: *Self, going_down: bool) void {
    self.level_config.going_down = going_down;
}

pub fn initLevel(self: *Self) !void {
    // FUTURE: world.configLevel()
    self.world.map = try level.create(self.level_config, &self.world);
}

pub fn deinitLevel(self: *Self) void {
    self.world.map.deinit(self.world.allocator); // NOCOMMIT
    self.world.map = undefined;
}

//
// Game Run
//

const level = @import("level.zig");

// Simple state machine: intro -> run -> end
pub const State = enum {
    run,
    descend, // hacky - let wrapper determine what this entails
    ascend,
    end,
};

// TODO: pull this into World
pub fn play(self: *Self) State {
    while (self.world.nextEvent()) |event| {
        const entity = event.entity; // FUTURE: other event types
        const result = entity.doAction(self.world.map) catch {
            return .end;
        };
        switch (result) {
            .continue_game => {
                // FUTURE: do not requeue - figure out how to do so from
                // an incoming command (via Client?).  Else server spins
                self.enqueueEntity(entity);
                continue;
            },
            .end_game => {
                self.world.map.removeEntity(entity.getPos());
                return .end;
            },
            // TODO: ascend/descend needs real map management and this breaks
            // the current 'rogue' model of new maps on the way back up

            .ascend => return .ascend,
            .descend => return .descend,
        }
    }

    // No entity left on queue
    return .run;
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

    var self: Self = .init;
    self.configAllocator(f.allocator());
    self.configIo(std.testing.io);
    // TODO: random
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

    var self: Self = .init;
    self.configAllocator(f.allocator());
    self.configIo(std.testing.io);
    // TODO: random
    defer self.deinit();

    var m = try MockClient.init(tallocator, 50, 50);
    defer m.deinit(tallocator);

    try expectError(error.OutOfMemory, self.initPlayer(.{ .client = m.client() }));
}

test "alloc failure 1" {
    var f = FailingAllocator.init(tallocator, .{ .fail_index = 1 });

    var self: Self = .init;
    self.configAllocator(f.allocator());
    self.configIo(std.testing.io);
    // TODO: random
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
