//!
//! Player, interfacing Entity
//!

const std = @import("std");

const Command = @import("roguelib").Command;
const Entity = @import("roguelib").Entity;
const MapTile = @import("roguelib").MapTile;
const Provider = @import("ui").Provider;

//
// Types
//

pub const Config = struct {
    provider: *Provider,
    allocator: std.mem.Allocator,
    maxx: u8,
    maxy: u8,
};

const player_vtable = Entity.VTable{
    .addMessage = playerAddMessage,
};

const Self = @This();

//
// Members
//

entity: Entity = undefined,
provider: *Provider = undefined,

//
// Constructor
//

pub fn init(config: Config) Self {
    return .{
        .entity = Entity.config(.player, &player_vtable),
        .provider = config.provider,
    };
}

//
// Vtable methods
//

fn playerAddMessage(ptr: *Entity, msg: []const u8) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.addMessage(msg);
}

//
// Methods
//

pub fn addMessage(self: *Self, msg: []const u8) void {
    self.provider.addMessage(msg);
}

pub fn getCommand(self: *Self) Command {
    return self.provider.getCommand();
}

//
// Unit Tests
//

const MockProvider = @import("ui").Mock;

test "create a player" {
    const mock_config = MockProvider.Config{
        .allocator = std.testing.allocator,
        .maxx = 10,
        .maxy = 10,
    };

    var m = try MockProvider.init(mock_config);
    defer m.deinit(std.testing.allocator);

    const config = Config{
        .provider = m.provider(),
        .allocator = std.testing.allocator,
        .maxx = 10,
        .maxy = 10,
    };

    _ = init(config);
}

// EOF
