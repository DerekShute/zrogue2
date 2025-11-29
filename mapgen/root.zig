//!
//! Level generation frontend
//!

const std = @import("std");
const Map = @import("roguelib").Map;
const Pos = @import("roguelib").Pos;

const createTestLevel = @import("test_level.zig").create;

//
// Encapsulate arguments
//

pub const Config = @import("utils.zig").Config;

//
// Interface Routine
//

pub fn createLevel(config: Config) !*Map {
    return switch (config.mapgen) {
        .TEST => try createTestLevel(config),
    };
}

//
// Unit Test Breakout
//

comptime {
    _ = @import("utils.zig");
}

test "create the test level" {
    const config = Config{
        .allocator = std.testing.allocator,
        .mapgen = .TEST,
    };

    var map = try createLevel(config);
    defer map.deinit();
}

// EOF
