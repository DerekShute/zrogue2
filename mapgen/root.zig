//!
//! Level generation frontend
//!

const std = @import("std");
const Map = @import("roguelib").Map;
const Pos = @import("roguelib").Pos;

const createTestLevel = @import("test_level.zig").create;
const createRogueLevel = @import("rogue_level.zig").create;

//
// Encapsulate arguments
//

pub const MapGenType = @import("utils.zig").MapGenType;
pub const Config = @import("utils.zig").Config;

//
// Interface Routine
//

pub fn create(config: Config, allocator: std.mem.Allocator) !*Map {
    return switch (config.mapgen) {
        .TEST => try createTestLevel(config, allocator),
        .ROGUE => try createRogueLevel(config, allocator),
    };
}

//
// Unit Test Breakout
//

comptime {
    _ = @import("utils.zig");
    _ = @import("rogue_level.zig");
}

test "create the test level" {
    const config = Config{
        .mapgen = .TEST,
    };

    var map = try create(config, std.testing.allocator);
    defer map.deinit(std.testing.allocator);
}

// EOF
