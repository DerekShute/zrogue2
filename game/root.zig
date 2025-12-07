//!
//! The game itself as a module to import from the various interfaces
//!

const std = @import("std");

const Action = @import("roguelib").Action;
const Pos = @import("roguelib").Pos;
const mapgen = @import("mapgen");
pub const Player = @import("Player.zig");
const Tileset = @import("roguelib").Tileset;

//
// Internals
//

// Simple state machine: intro -> run -> end
const State = enum {
    run,
    end,
};

// Return value from ActionGameHandler
const ActionResult = enum {
    continue_game, // Game still in progress
    end_game, // Quit, death, etc.
    ascend,
    descend,
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

    while (state != .end) {
        var result: ActionResult = .continue_game;

        var map = try mapgen.create(mapgen_config, allocator);
        defer map.deinit(allocator);

        // TODO for now, reveal the map
        var i = map.iterator();
        while (i.next()) |loc| {
            const ts = map.getTileset(loc);
            render(player, ts, loc);
        }

        while (result == .continue_game) {
            var action = player.getAction();

            if (action.getType() == .quit) {
                result = .end_game;
            }
        }

        // TODO this is driven by action follow-through
        state = .end;
    }
}

//
// Unit Tests
//

comptime {
    _ = @import("Player.zig");
}

// EOF
