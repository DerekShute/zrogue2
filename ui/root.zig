//!
//! UI wrappers and implementations
//!

pub const std = @import("std");
pub const Provider = @import("Provider.zig");
pub const Mock = @import("Mock.zig");

//
// Types
//

pub const MockConfig = Mock.Config;
pub const initMock = Mock.init;
pub const deinitMock = Mock.deinit;

//
// Routines
//

//
// Unit Tests
//

comptime {
    _ = @import("Provider.zig");
    _ = @import("Mock.zig");
}

// EOF
