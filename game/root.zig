//!
//! The game itself as a module to import from the various interfaces
//!

const ui = @import("ui");

//
// Routines
//

pub fn run_game(provider: *ui.Provider) void {
    _ = provider.getCommand();
}

// EOF
