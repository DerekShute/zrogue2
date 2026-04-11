//!
//! Testing map rendering
//!
//! This is kind of a bug fountain
//!

const std = @import("std");
const game = @import("game");
const Action = @import("roguelib").Action;
const Client = @import("roguelib").Client;
const Map = @import("roguelib").Map;
const Pos = @import("roguelib").Pos;
const MapTile = @import("roguelib").MapTile;

const expect = std.testing.expect;
const MockClient = @import("MockClient.zig");
const level = @import("level.zig");

const XSIZE = 80;
const YSIZE = 24;

//
// Utilities
//

fn makeClient(testlist: []Client.Command) !MockClient {
    return try MockClient.init(.{
        .allocator = std.testing.allocator,
        .maxx = XSIZE,
        .maxy = YSIZE,
        .commands = testlist,
    });
}

fn makePlayer(client: *Client) game.Player {
    return game.Player.init(.{
        .allocator = std.testing.allocator,
        .client = client,
        .maxx = XSIZE,
        .maxy = YSIZE,
    });
}

fn makeMap(player: *game.Player) !*Map {
    return try level.create(std.testing.allocator, player.getEntity());
}

fn getEntity(c: *Client, x: i16, y: i16) MapTile {
    const dt = c.getTile(Pos.config(x, y));
    return dt.entity;
}

fn getFloor(c: *Client, x: i16, y: i16) MapTile {
    const dt = c.getTile(Pos.config(x, y));
    return dt.floor;
}

fn getItem(c: *Client, x: i16, y: i16) MapTile {
    const dt = c.getTile(Pos.config(x, y));
    return dt.item;
}

fn isVisible(c: *Client, x: i16, y: i16) bool {
    const dt = c.getTile(Pos.config(x, y));
    return dt.visible;
}

fn moveTo(player: *game.Player, map: *Map, pos: Pos) void {
    const orig = player.getPos();
    map.removeEntity(orig);
    player.setPos(pos);
    map.addEntity(player.getEntity(), player.getPos());
    player.revealMap(map, orig);
}

fn expectFloor(c: *Client, x: i16, y: i16, t: MapTile, v: bool) !void {
    try expect(getFloor(c, x, y) == t);
    try expect(isVisible(c, x, y) == v);
}

//
// Tests: consult the test_level map
//

test "render starting position" {
    var testlist = [_]Client.Command{
        .wait,
        .ascend,
        .descend,
        .quit,
    };

    var mock = try makeClient(&testlist);
    defer mock.deinit(std.testing.allocator);
    const client = mock.client();
    var player = makePlayer(client);
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

    try expectFloor(client, 2, 2, .unknown, false);
    try expectFloor(client, 6, 6, .floor, true);
    try expect(getEntity(client, 6, 6) == .player);
    try expect(getItem(client, 6, 6) == .unknown);
    try expectFloor(client, 7, 5, .floor, true);
    try expect(getItem(client, 7, 5) == .gold);
    try expectFloor(client, 8, 4, .unknown, false); // stairs down, not updated

    //       ###
    //       .@<
    //       ..>

    moveTo(&player, map, Pos.config(7, 3));
    try expectFloor(client, 6, 6, .floor, false); // no update, not visible
    try expectFloor(client, 7, 2, .wall, true); // visible
    try expectFloor(client, 8, 4, .stairs_down, true);
    try expectFloor(client, 8, 3, .stairs_up, true);

    //                            #########
    //                            #.......#
    //                            #...@...#
    //                            ........#
    //                            #.......#
    //                            #########

    moveTo(&player, map, Pos.config(31, 7));
    try expectFloor(client, 27, 5, .wall, true); // lit room
    try expectFloor(client, 27, 10, .wall, true);
    try expectFloor(client, 35, 5, .wall, true);
    try expectFloor(client, 35, 10, .wall, true);
    try expectFloor(client, 31, 7, .floor, true);

    //                            #########
    //                            #       #
    //                          ###       #
    //                          .@.       #
    //                          ###       #
    //                            #########

    moveTo(&player, map, Pos.config(26, 8));
    try expectFloor(client, 25, 8, .floor, true);
    try expectFloor(client, 31, 7, .floor, false);

    //                            #########
    //                            #.......#
    //                          ###.......#
    //                           .@.......#
    //                          ###.......#
    //                            #########

    moveTo(&player, map, Pos.config(27, 8));
    try expectFloor(client, 25, 8, .floor, false);
    try expectFloor(client, 31, 7, .floor, true);

    //                            #########
    //                            #.......#
    //                          ###.......#
    //                            .@......#
    //                          ###.......#
    //                            #########
    moveTo(&player, map, Pos.config(28, 8));
    try expectFloor(client, 26, 8, .floor, false);
    try expectFloor(client, 31, 7, .floor, true);
}

// EOF
