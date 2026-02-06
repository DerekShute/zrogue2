//!
//! The game itself as a module to import from the various interfaces
//!

const std = @import("std");

const Action = @import("roguelib").Action;
const Entity = @import("roguelib").Entity;
const Pos = @import("roguelib").Pos;
const Map = @import("roguelib").Map;
const mapgen = @import("mapgen");
pub const Player = @import("Player.zig");
const Tileset = @import("roguelib").Tileset;

const level = @import("level.zig");

const util = @import("util.zig");

//
// Configuration
//

const MAX_DEPTH = 3;

pub const Config = struct {
    player: *Player,
    allocator: std.mem.Allocator,
};

//
// Testing Conveniences
//

pub const doAction = util.doAction;

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

fn play(config: *level.Config, map: *Map, queue: *Entity.Queue) State {
    var result: Action.Result = undefined;
    var state: State = .run;

    // FUTURE: Other Entities means having a .depart result

    while (queue.next()) |entity| {
        result = util.doAction(entity, map);
        if (result != .continue_game) {
            break;
        }
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

pub fn run(config: Config) !void {
    const player = config.player;
    const entity = player.getEntity();
    const allocator = config.allocator;

    const seed: u64 = @intCast(std.time.microTimestamp());
    var prng = std.Random.DefaultPrng.init(seed);
    var r = prng.random();

    var level_config: level.Config = .{
        .rand = &r,
    };

    player.addMessage("Welcome to the Dungeon of Doom!");

    var queue = Entity.Queue.config();

    var state: State = .run;
    while (state != .end) {
        var map = try level.create(level_config, allocator);
        defer map.deinit(allocator);

        level.addPlayer(map, player, &r);
        queue.enqueue(entity);
        state = play(&level_config, map, &queue);
    } // Game run loop

    // TODO : game endings go here
}

//
// Unit Tests
//

comptime {
    _ = @import("Player.zig");
    _ = @import("util.zig");
}

// EOF
