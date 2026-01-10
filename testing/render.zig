//!
//! Testing map rendering
//!
//! This is kind of a bug fountain
//!

const std = @import("std");
const game = @import("game");
const Action = @import("roguelib").Action;
const Map = @import("roguelib").Map;
const Pos = @import("roguelib").Pos;
const mapgen = @import("mapgen");
const MapTile = @import("roguelib").MapTile;
const ui = @import("ui");
const Provider = ui.Provider;

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

fn getEntity(p: *Provider, x: i16, y: i16) MapTile {
    const dt = p.getTile(x, y);
    return dt.entity;
}

fn getFloor(p: *Provider, x: i16, y: i16) MapTile {
    const dt = p.getTile(x, y);
    return dt.floor;
}

fn getItem(p: *Provider, x: i16, y: i16) MapTile {
    const dt = p.getTile(x, y);
    return dt.item;
}

fn isVisible(p: *Provider, x: i16, y: i16) bool {
    const dt = p.getTile(x, y);
    return dt.visible;
}

fn moveTo(player: *game.Player, map: *Map, pos: Pos) void {
    const orig = player.getPos();
    map.removeEntity(orig);
    player.setPos(pos);
    map.addEntity(player.getEntity(), player.getPos());
    player.revealMap(map, orig);
}

fn expectFloor(p: *Provider, x: i16, y: i16, t: MapTile, v: bool) !void {
    try expect(getFloor(p, x, y) == t);
    try expect(isVisible(p, x, y) == v);
}

//
// Tests: consult the test_level map
//

test "render starting position" {
    var testlist = [_]ui.Provider.Command{
        .wait,
        .ascend,
        .descend,
        .quit,
    };

    var mock = try makeProvider(&testlist);
    defer mock.deinit(std.testing.allocator);
    const provider = mock.provider();
    var player = makePlayer(provider);
    var map = try makeMap(&player);
    defer map.deinit(std.testing.allocator);

    var i = map.iterator(); // TODO this is dumb
    while (i.next()) |p| {
        player.setUnknown(p);
    }
    player.revealMap(map, player.getPos());

    // Initial position: adjacent flooring is visible, else unknown
    //      ..$
    //      .@.
    //      ...

    try expectFloor(provider, 2, 2, .unknown, false);
    try expectFloor(provider, 6, 6, .floor, true);
    try expect(getEntity(provider, 6, 6) == .player);
    try expect(getItem(provider, 6, 6) == .unknown);
    try expectFloor(provider, 7, 5, .floor, true);
    try expect(getItem(provider, 7, 5) == .gold);
    try expectFloor(provider, 8, 4, .unknown, false); // stairs down, not updated

    //       ###
    //       .@<
    //       ..>

    moveTo(&player, map, Pos.config(7, 3));
    try expectFloor(provider, 6, 6, .floor, false); // no update, not visible
    try expectFloor(provider, 7, 2, .wall, true); // visible
    try expectFloor(provider, 8, 4, .stairs_down, true);
    try expectFloor(provider, 8, 3, .stairs_up, true);

    //                            #########
    //                            #.......#
    //                            #...@...#
    //                            ........#
    //                            #.......#
    //                            #########

    moveTo(&player, map, Pos.config(31, 7));
    try expectFloor(provider, 27, 5, .wall, true); // lit room
    try expectFloor(provider, 27, 10, .wall, true);
    try expectFloor(provider, 35, 5, .wall, true);
    try expectFloor(provider, 35, 10, .wall, true);
    try expectFloor(provider, 31, 7, .floor, true);

    //                            #########
    //                            #       #
    //                          ###       #
    //                          .@.       #
    //                          ###       #
    //                            #########

    moveTo(&player, map, Pos.config(26, 8));
    try expectFloor(provider, 25, 8, .floor, true);
    try expectFloor(provider, 31, 7, .floor, false);

    //                            #########
    //                            #.......#
    //                          ###.......#
    //                           .@.......#
    //                          ###.......#
    //                            #########

    moveTo(&player, map, Pos.config(27, 8));
    try expectFloor(provider, 25, 8, .floor, false);
    try expectFloor(provider, 31, 7, .floor, true);

    //                            #########
    //                            #.......#
    //                          ###.......#
    //                            .@......#
    //                          ###.......#
    //                            #########
    moveTo(&player, map, Pos.config(28, 8));
    try expectFloor(provider, 26, 8, .floor, false);
    try expectFloor(provider, 31, 7, .floor, true);
}
