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

fn render(player: *Player, ts: Tileset, p: Pos) void {

    // Eventual considerations:
    //  * in room?
    //  * dark?
    //  * invisibility?
    //  * blindness?
    //
    // TODO: SetKnown should accept all three; let provider figure it out

    if (ts.entity != .unknown) {
        player.setTileKnown(p, ts.entity);
    } else if (ts.item != .unknown) {
        player.setTileKnown(p, ts.item);
    } else {
        player.setTileKnown(p, ts.floor);
    }
}

//
// Run the game
//

// Public for use in testing
pub fn step(player: *Player, map: *Map) Action.Result {
    var action = player.getAction();
    return util.doPlayerAction(player, &action, map);
}

// TODO: this probably goes in its own file
pub fn run(player: *Player, allocator: std.mem.Allocator) !void {
    var state: State = .run;
    player.addMessage("Welcome to the Dungeon of Doom!");

    var mapgen_config: mapgen.Config = .{
        .player = player.getEntity(),
        .mapgen = .TEST,
    };

    while (state == .run) {
        var result: Action.Result = .continue_game;

        var map = try mapgen.create(mapgen_config, allocator);
        defer map.deinit(allocator);

        player.setDepth(mapgen_config.level);

        // TODO: doPlayerAction goes into Player, eventually Entity vtable
        while (result == .continue_game) {
            // TODO for now, reveal the map
            // TODO: this is of course very hokey
            var i = map.iterator();
            while (i.next()) |loc| {
                const ts = map.getTileset(loc);
                render(player, ts, loc);
            }

            result = step(player, map);
            switch (result) {
                .continue_game => {}, // Do nothing, keep going
                .end_game => {
                    state = .end;
                },
                .descend => {
                    mapgen_config.level += 1;
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
