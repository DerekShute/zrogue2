//!
//! The game itself as a module to import from the various interfaces
//!

const std = @import("std");
const Pos = @import("roguelib").Pos;
const mapgen = @import("mapgen");
pub const Player = @import("Player.zig");

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
// Routines
//

// TODO: this probably goes in its own file
pub fn run(player: *Player, allocator: std.mem.Allocator) !void {
    var state: State = .run;
    player.addMessage("Welcome to the Dungeon of Doom!");

    const mapgen_config: mapgen.Config = .{
        .mapgen = .TEST,
    };

    while (state != .end) {
        var result: ActionResult = .continue_game;

        var map = try mapgen.create(mapgen_config, allocator);
        defer map.deinit(allocator);

        // TODO displaying map as mapgen convenience
        for (0..@intCast(map.getHeight())) |y| {
            for (0..@intCast(map.getWidth())) |x| {
                const loc = Pos.config(@intCast(x), @intCast(y));
                const t = map.getFloorTile(loc);
                player.setTileKnown(loc, t);
            }
        }

        while (result == .continue_game) {
            // TODO this becomes a getAction
            const cmd = player.getCommand();
            if (cmd == .quit) {
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
