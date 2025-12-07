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

test "quit the game" {
    var testlist = [_]ui.Provider.Command{
        .quit,
    };

    var m = try makeProvider(&testlist);
    defer m.deinit(std.testing.allocator);
    var player = makePlayer(m.provider());
    var map = try makeMap(&player);
    defer map.deinit(std.testing.allocator);

    try expect(player.getPos().getX() == 6);
    try expect(player.getPos().getY() == 6);
    try expect(game.step(&player, map) == .end_game);
    try expect(player.getPos().getX() == 6);
    try expect(player.getPos().getY() == 6);
}

test "move in a circle" {
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

// Add long sequences and test for expected value

// EOF
