//!
//! The game itself as a module to import from the various interfaces
//!

const std = @import("std");

const Action = @import("roguelib").Action;
const Pos = @import("roguelib").Pos;
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

// TODO this goes in provider or something?
fn render(player: *Player, ts: Tileset, p: Pos) void {

    // Eventual considerations:
    //  * in room?
    //  * dark?
    //  * invisibility?
    //  * blindness?

    if (ts.entity != .unknown) {
        player.setTileKnown(p, ts.entity);
    } else {
        player.setTileKnown(p, ts.floor);
    }
}

//
// Run the game
//

// TODO: this probably goes in its own file
pub fn run(player: *Player, allocator: std.mem.Allocator) !void {
    var state: State = .run;
    player.addMessage("Welcome to the Dungeon of Doom!");

    const mapgen_config: mapgen.Config = .{
        .player = player.getEntity(),
        .mapgen = .TEST,
    };

    while (state == .run) {
        var result: Action.Result = .continue_game;

        var map = try mapgen.create(mapgen_config, allocator);
        defer map.deinit(allocator);

        // TODO: doPlayerAction goes into Player, eventually Entity vtable
        while (result == .continue_game) {
            // TODO for now, reveal the map
            // TODO: this is of course very hokey
            var i = map.iterator();
            while (i.next()) |loc| {
                const ts = map.getTileset(loc);
                render(player, ts, loc);
            }

            var action = player.getAction();
            result = util.doPlayerAction(player, &action, map);
        }

        if (result == .end_game) {
            state = .end;
        }
    }
}

//
// Unit Tests
//

comptime {
    _ = @import("Player.zig");
    _ = @import("util.zig");
}

// EOF
