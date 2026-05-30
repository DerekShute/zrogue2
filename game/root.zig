//!
//! The game itself as a module to import from the various interfaces
//!
//! Mostly a primitive original Rogue
//!

const std = @import("std");

const Action = @import("roguelib").Action;
const Entity = @import("roguelib").Entity;
const features = @import("features.zig");
const FOVMap = @import("roguelib").FOVMap;
const Game = @import("Game.zig");
const Map = @import("roguelib").Map;
const mapgen = @import("mapgen.zig");
pub const MapTile = mapgen.MapTile;
pub const Player = @import("Player.zig");
const Pos = @import("roguelib").Pos;

const level = @import("level.zig");

const actions = @import("actions.zig");

//
// Configuration
//

pub const XSIZE = mapgen.XSIZE;
pub const YSIZE = mapgen.YSIZE;

const MAX_DEPTH = 3;

pub const Config = struct {
    player: *Player,
    allocator: std.mem.Allocator,
    seed: i64 = undefined,
};

//
// Testing Conveniences
//

pub const doAction = actions.doAction;

//
// Internals
//

// Simple state machine: intro -> run -> end
const State = enum {
    run,
    end,
};

//
// Utilities
//

fn play(config: *mapgen.Config, map: *Map, queue: *Entity.Queue) State {
    var result: Action.Result = undefined;
    var state: State = .run;

    // FUTURE: Other Entities means having a .depart result

    while (queue.next()) |entity| {
        result = doAction(entity, map) catch {
            return .end;
        };
        if (result != .continue_game) {
            break;
        }
        entity.notifyDisplay(map);
        queue.enqueue(entity); // Continues
    }

    switch (result) {
        .continue_game => unreachable,
        .end_game => state = .end,
        .descend => {
            config.level += 1;
            if (config.level >= MAX_DEPTH) {
                config.going_down = false;
            }
        },
        .ascend => {
            config.level -= 1;
            if (config.level < 1) {
                state = .end;
            }
        },
    }
    return state;
}

//
// Run the game
//

pub fn getMaxXY() [2]i16 {
    return [2]i16{ XSIZE, YSIZE };
}

pub fn run(config: Config) !void {
    const player = config.player;
    const entity = player.getEntity();
    const allocator = config.allocator;

    var prng = std.Random.DefaultPrng.init(@intCast(config.seed));
    var r = prng.random();
    var level_config = mapgen.Config.init;

    player.addMessage("Welcome to the Dungeon of Doom!");

    var fov = try FOVMap.init(allocator, XSIZE, YSIZE);
    defer fov.deinit(allocator);
    entity.setFOV(&fov);

    var queue = Entity.Queue.config();
    var state: State = .run;

    while (state != .end) {
        var map = try level.create(level_config, allocator, &r);
        defer map.deinit(allocator);

        level.addPlayer(map, player, &r);
        queue.enqueue(entity);
        state = play(&level_config, map, &queue);
        fov.reset();
    } // Game run loop

    // FUTURE: game endings go here
}

//
// Unit Tests
//

comptime {
    _ = @import("Game.zig");
    _ = @import("level.zig");
    _ = @import("mapgen.zig");
    _ = @import("testing/actions.zig");
    _ = @import("testing/level.zig");
    _ = @import("testing/main.zig");
    _ = @import("testing/render.zig");
}

// EOF
