//!
//! UI wrappers and implementations
//!

pub const std = @import("std");
pub const Provider = @import("Provider.zig");
pub const Curses = @import("Curses.zig");

//
// Types
//

pub const CursesConfig = Curses.Config;
pub const initCurses = Curses.init;
pub const deinitCurses = Curses.deinit;

//
// Routines
//

//
// Unit Tests
//

comptime {
    _ = @import("Provider.zig");
    _ = @import("Curses.zig");
}

// EOF
