//!
//! The game itself as a module to import from the various interfaces
//!

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

pub fn run(player: *Player) void {
    var state: State = .run;
    player.addMessage("Welcome to the Dungeon of Doom!");

    while (state != .end) {
        var result: ActionResult = .continue_game;

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
