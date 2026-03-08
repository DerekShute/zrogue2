//!
//! Generate visualization of common structures
//!
//!
//! This is built and run as part of the 'visual' target and outputs
//! a handcrafted YAML description of structures within instrumented
//! modules.
//!
//! A Python script will take this YAML and format the Graphviz
//! diagram.

const std = @import("std");

const Action = @import("Action.zig");
const Client = @import("Client.zig");
const Entity = @import("Entity.zig");
const Feature = @import("Feature.zig");
const Map = @import("Map.zig");
const Pos = @import("Pos.zig");
const Region = @import("Region.zig");
const Remote = @import("Remote.zig");
const Tileset = @import("maptile.zig"); // Slightly a lie

fn printer(array: []const []const u8) void {
    for (array) |name| {
        std.debug.print("{s}\n", .{name});
    }
}

pub fn main() !void {
    std.debug.print("---\n", .{});
    printer(Action.fields);
    printer(Client.fields);
    printer(Client.log_fields);
    printer(Entity.fields);
    printer(Feature.fields);
    printer(Map.fields);
    printer(Map.place_fields);
    printer(Map.room_fields);
    printer(Pos.fields);
    printer(Region.fields);
    printer(Remote.fields);
    printer(Tileset.fields);
}

// EOF
