//!
//! Player, interfacing Entity
//!

const std = @import("std");

const Action = @import("roguelib").Action;
const Entity = @import("roguelib").Entity;
const MapTile = @import("roguelib").MapTile;
const Pos = @import("roguelib").Pos;
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
// Utility
//

fn getCommand(self: *Self) Provider.Command {
    return self.provider.getCommand();
}

//
// Methods
//

pub fn addMessage(self: *Self, msg: []const u8) void {
    self.provider.addMessage(msg);
}

pub fn getMessage(self: *Self) []const u8 {
    return self.provider.getMessage();
}

pub fn getAction(self: *Self) Action {
    return switch (self.getCommand()) {
        .help => Action.config(.none),
        .quit => Action.config(.quit),
        .go_north => Action.configDir(.move, .north),
        .go_east => Action.configDir(.move, .east),
        .go_south => Action.configDir(.move, .south),
        .go_west => Action.configDir(.move, .west),
        .ascend => Action.config(.ascend),
        .descend => Action.config(.descend),
        .search => Action.config(.search),
        .take_item => Action.configPos(.take, self.getPos()),
        else => Action.config(.wait),
    };
}

pub fn getEntity(self: *Self) *Entity {
    return &self.entity;
}

pub fn setTileKnown(self: *Self, loc: Pos, tile: MapTile) void {
    self.provider.setTile(@intCast(loc.getX()), @intCast(loc.getY()), tile);
}

pub fn getPos(self: *Self) Pos {
    return self.entity.getPos();
}

pub fn setPos(self: *Self, p: Pos) void {
    self.entity.setPos(p);
}

pub fn takeItem(self: *Self, i: MapTile) void {
    // TODO Assumes item, inventory, etc.
    if (i == .gold) {
        self.addMessage("You pick up the gold!");
        // TODO: purse
    } else {
        self.addMessage("Nothing here to take!");
    }
}

//
// Unit Tests
//

const expect = std.testing.expect;
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

    var player = init(config);

    player.setTileKnown(Pos.config(0, 0), .floor);

    // Position identity

    const p = Pos.config(10, 10);
    player.setPos(p);
    try expect(p.eql(player.getPos()));
}

// EOF
