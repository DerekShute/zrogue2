//!
//! Test the end-to-end
//!

const std = @import("std");
const mapgen = @import("../mapgen.zig");
const Game = @import("../root.zig");
const MockClient = @import("roguelib").MockClient;
const Client = @import("roguelib").Client;

//
// Unit Tests
//

var testlist = [_]Client.Command{
    .wait, // do nothing
    .go_west,
    .go_east,
    .go_north,
    .go_south,
    .ascend,
    .descend,
    .search,
    .take_item,
    .go_north,
    .go_east,
    .take_item, // gold
    .search, // find trap
    .go_east, // step on trap
    .search, // find secret door
    .go_north,
    .descend, // "level two"
    .go_north,
    .go_north,
    .go_north,
    .go_east,
    .go_east,
    .ascend, // back to "level one"
    .quit,
};

test "run the game" {
    var m = try MockClient.init(std.testing.allocator, mapgen.XSIZE, mapgen.YSIZE);
    defer m.deinit(std.testing.allocator);
    m.setCommandList(&testlist);

    const seed = std.Io.Timestamp.now(std.testing.io, .real).toMicroseconds();
    var prng: std.Random.DefaultPrng = .init(@intCast(seed));

    var g: Game = .init;
    g.configAllocator(std.testing.allocator);
    g.configIo(std.testing.io);
    g.configRandom(prng.random());
    defer g.deinit();

    const id = try g.initPlayer(.{ .client = m.client() });
    defer g.deinitPlayer(id);

    try g.initLevel();
    defer g.deinitLevel();

    g.addPlayer(g.getPlayer(id)); // TODO: ugh

    var state: Game.State = .run;
    while (state != .end) {
        state = g.play();
    } // Game run loop
}

// EOF
