//!
//! Testing actions
//!

const std = @import("std");
const game = @import("game");
const Action = @import("roguelib").Action;
const Map = @import("roguelib").Map;
const Pos = @import("roguelib").Pos;
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

fn step(player: *game.Player, map: *Map, val: Action.Result) !void {
    var entity = player.getEntity();
    try expect(entity.doAction(map) == val);
}

fn stepXY(
    player: *game.Player,
    map: *Map,
    val: Action.Result,
    x: Pos.Dim,
    y: Pos.Dim,
) !void {
    try step(player, map, val);
    try expect(player.getPos().getX() == x);
    try expect(player.getPos().getY() == y);
}

fn actAndMessage(player: *game.Player, map: *Map, msg: []const u8) !void {
    try step(player, map, .continue_game);
    try expect(std.mem.eql(u8, player.getMessage(), msg));
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

    try step(&player, map, .continue_game);
    try step(&player, map, .continue_game);
    try step(&player, map, .continue_game);
    try step(&player, map, .end_game);
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

    try stepXY(&player, map, .continue_game, 5, 6);
    try stepXY(&player, map, .continue_game, 5, 5);
    try stepXY(&player, map, .continue_game, 6, 5);
    try stepXY(&player, map, .continue_game, 6, 6);
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

    try stepXY(&player, map, .continue_game, 7, 6);
    try stepXY(&player, map, .continue_game, 8, 6);
    try stepXY(&player, map, .continue_game, 8, 6); // Bonk
}

// Expand this as capabilities add...
test "pick up gold and etc" {
    // TODO: instrument the mock provider so you can insert/replace items, so
    // changing this around is easier
    var testlist = [_]ui.Provider.Command{
        .search, // find nothing
        .go_east,
        .go_north,
        .take_item,
        .wait,
        .go_east, // on trap
        .search, // find secret door
        .go_north,
        .descend,
        .go_north,
        .ascend,
    };

    var m = try makeProvider(&testlist);
    defer m.deinit(std.testing.allocator);
    var player = makePlayer(m.provider());
    var map = try makeMap(&player);
    defer map.deinit(std.testing.allocator);

    try expect(player.getMessage().len == 0);

    try actAndMessage(&player, map, "You find nothing!"); // search

    try step(&player, map, .continue_game);
    try step(&player, map, .continue_game);

    try expect(map.getItem(player.getPos()) == .gold);
    try expect(m.stats.purse == 0);
    try actAndMessage(&player, map, "You pick up the gold!"); // take
    try expect(map.getItem(player.getPos()) == .unknown);
    // Stat update appears at next getCommand
    try step(&player, map, .continue_game);
    try expect(m.stats.purse == 1);

    try actAndMessage(&player, map, "You step on a trap!"); // go east
    try expect(map.getFloorTile(Pos.config(8, 5)) == .trap);

    try expect(map.getFloorTile(Pos.config(9, 5)) == .wall);

    try actAndMessage(&player, map, "You find something!"); // search
    try expect(map.getFloorTile(Pos.config(9, 5)) == .door); // secret door

    try step(&player, map, .continue_game);
    try step(&player, map, .descend);
    try expect(std.mem.eql(
        u8,
        player.getMessage(),
        "You go ever deeper into the dungeon...",
    ));

    try step(&player, map, .continue_game);
    try step(&player, map, .ascend);
    try expect(std.mem.eql(
        u8,
        player.getMessage(),
        "You ascend closer to the exit...",
    ));
}

// EOF
