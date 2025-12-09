//!
//! Testing actions
//!

const std = @import("std");
const game = @import("game");
const Action = @import("roguelib").Action;
const Map = @import("roguelib").Map;
const mapgen = @import("mapgen");
const ui = @import("ui");

const expect = std.testing.expect;
const MockProvider = @import("MockProvider.zig");

const XSIZE = 80;
const YSIZE = 24;

//
// Utilities
//

fn makeProvider(testlist: []ui.Provider.Command) !MockProvider {
    return try MockProvider.init(.{
        .allocator = std.testing.allocator,
        .maxx = XSIZE,
        .maxy = YSIZE,
        .commands = testlist,
    });
}

fn makePlayer(provider: *ui.Provider) game.Player {
    return game.Player.init(.{
        .allocator = std.testing.allocator,
        .provider = provider,
        .maxx = XSIZE,
        .maxy = YSIZE,
    });
}

fn makeMap(player: *game.Player) !*Map {
    return try mapgen.create(
        .{
            .player = player.getEntity(),
            .mapgen = .TEST,
        },
        std.testing.allocator,
    );
}

//
// Tests: consult the test_level map
//

test "in-place boring stuff then quit" {
    var testlist = [_]ui.Provider.Command{
        .wait,
        .ascend,
        .descend,
        .quit,
    };

    var m = try makeProvider(&testlist);
    defer m.deinit(std.testing.allocator);
    var player = makePlayer(m.provider());
    var map = try makeMap(&player);
    defer map.deinit(std.testing.allocator);

    try expect(game.step(&player, map) == .continue_game);
    try expect(game.step(&player, map) == .continue_game);
    try expect(game.step(&player, map) == .continue_game);
    try expect(game.step(&player, map) == .end_game);
}

test "move in a circle: all directions work" {
    var testlist = [_]ui.Provider.Command{
        .go_west,
        .go_north,
        .go_east,
        .go_south,
    };

    var m = try makeProvider(&testlist);
    defer m.deinit(std.testing.allocator);
    var player = makePlayer(m.provider());
    var map = try makeMap(&player);
    defer map.deinit(std.testing.allocator);

    try expect(game.step(&player, map) == .continue_game);
    try expect(player.getPos().getX() == 5);
    try expect(player.getPos().getY() == 6);

    try expect(game.step(&player, map) == .continue_game);
    try expect(player.getPos().getX() == 5);
    try expect(player.getPos().getY() == 5);

    try expect(game.step(&player, map) == .continue_game);
    try expect(player.getPos().getX() == 6);
    try expect(player.getPos().getY() == 5);

    try expect(game.step(&player, map) == .continue_game);
    try expect(player.getPos().getX() == 6);
    try expect(player.getPos().getY() == 6);
}

test "hit a wall" {
    var testlist = [_]ui.Provider.Command{
        .go_east,
        .go_east,
        .go_east,
    };

    var m = try makeProvider(&testlist);
    defer m.deinit(std.testing.allocator);
    var player = makePlayer(m.provider());
    var map = try makeMap(&player);
    defer map.deinit(std.testing.allocator);

    try expect(game.step(&player, map) == .continue_game);
    try expect(game.step(&player, map) == .continue_game);
    try expect(player.getPos().getX() == 8);
    try expect(game.step(&player, map) == .continue_game);
    try expect(player.getPos().getX() == 8); // Bonk
    try expect(player.getPos().getY() == 6);
}

// Expand this as capabilities add...
test "pick up gold and etc" {
    var testlist = [_]ui.Provider.Command{
        .go_east,
        .go_north,
        .take_item,
        .wait,
        .go_north,
        .go_east,
        .descend,
        .go_north,
        .ascend,
    };

    var m = try makeProvider(&testlist);
    defer m.deinit(std.testing.allocator);
    var player = makePlayer(m.provider());
    var map = try makeMap(&player);
    defer map.deinit(std.testing.allocator);

    try expect(game.step(&player, map) == .continue_game);
    try expect(game.step(&player, map) == .continue_game);

    try expect(map.getItem(player.getPos()) == .gold);
    try expect(player.getMessage().len == 0);
    try expect(m.stats.purse == 0);
    try expect(game.step(&player, map) == .continue_game);
    try expect(std.mem.eql(u8, player.getMessage(), "You pick up the gold!"));
    try expect(map.getItem(player.getPos()) == .unknown);

    // Stat update appears at next getCommand
    try expect(game.step(&player, map) == .continue_game);
    try expect(m.stats.purse == 1);

    try expect(game.step(&player, map) == .continue_game);
    try expect(game.step(&player, map) == .continue_game);
    try expect(game.step(&player, map) == .descend);
    try expect(std.mem.eql(
        u8,
        player.getMessage(),
        "You go ever deeper into the dungeon...",
    ));

    try expect(game.step(&player, map) == .continue_game);
    try expect(game.step(&player, map) == .ascend);
    try expect(std.mem.eql(
        u8,
        player.getMessage(),
        "You ascend closer to the exit...",
    ));
}

// EOF
