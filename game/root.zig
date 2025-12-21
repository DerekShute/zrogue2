//!
//! The game itself as a module to import from the various interfaces
//!

const std = @import("std");

const Action = @import("roguelib").Action;
const Pos = @import("roguelib").Pos;
const Map = @import("roguelib").Map;
const mapgen = @import("mapgen");
pub const Player = @import("Player.zig");
const Tileset = @import("roguelib").Tileset;
const util = @import("util.zig");

//
// Configuration
//

const MAX_DEPTH = 3;

pub const Config = struct {
    player: *Player,
    allocator: std.mem.Allocator,
    gentype: mapgen.MapGenType,
};

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

//
// Run the game
//

// Public for use in testing
pub fn step(player: *Player, map: *Map) Action.Result {
    var action = player.getAction();
    return util.doPlayerAction(player, &action, map);
}

// TODO: this probably goes in its own file
pub fn run(config: Config) !void {
    const player = config.player;
    const allocator = config.allocator;

    const seed: u64 = @intCast(std.time.microTimestamp());
    var prng = std.Random.DefaultPrng.init(seed);
    var r = prng.random();

    var mapgen_config: mapgen.Config = .{
        .rand = &r,
        .player = player.getEntity(),
        .xSize = 80, // TODO, eventually other ideas
        .ySize = 24,
        .mapgen = config.gentype,
    };

    var state: State = .run;
    player.addMessage("Welcome to the Dungeon of Doom!");
    while (state == .run) {
        var result: Action.Result = .continue_game;

        var map = try mapgen.create(mapgen_config, allocator);
        defer map.deinit(allocator);

        var i = map.iterator();
        while (i.next()) |p| {
            player.setUnknown(p);
        }

        player.setDepth(mapgen_config.level);
        util.revealMap(player, map, player.getPos()); // initial position

        // TODO: doPlayerAction goes into Player, eventually Entity vtable
        while (result == .continue_game) {
            result = step(player, map);
            switch (result) {
                .continue_game => {}, // Do nothing, keep going
                .end_game => {
                    state = .end;
                },
                .descend => {
                    mapgen_config.level += 1;
                    if (mapgen_config.level >= MAX_DEPTH) {
                        mapgen_config.going_down = false;
                    }
                },
                .ascend => {
                    mapgen_config.level -= 1;
                    if (mapgen_config.level < 1) {
                        state = .end;
                    }
                },
            }
        } // Play on level loop
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
