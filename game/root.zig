//!
//! The game itself as a module to import from the various interfaces
//!

pub const Player = @import("Player.zig");

//
// Routines
//

pub fn run(player: *Player) void {
    player.addMessage("Welcome to the Dungeon of Doom!");
    _ = player.getCommand();
}

//
// Unit Tests
//

comptime {
    _ = @import("Player.zig");
}

// EOF
