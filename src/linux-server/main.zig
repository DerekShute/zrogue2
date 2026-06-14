//!
//! Linux cli-based server
//!

const std = @import("std");
const Game = @import("game");
const RemoteClient = @import("RemoteClient.zig");

const Allocator = std.mem.Allocator;

const log = std.log.scoped(.server);
const net = std.Io.net;

//
// Client connection
//

fn handleClient(g: *Game, conn: *net.Stream) !void {
    defer conn.close(g.io);

    const name = try std.fmt.allocPrint(g.allocator, "{f}", .{conn.socket.address});
    defer g.allocator.free(name);

    log.info("[{s}] Accepted connection", .{name}); // FUTURE into Player

    const rbuf = try g.allocator.alloc(u8, 1024);
    defer g.allocator.free(rbuf);
    var reader = conn.reader(g.io, rbuf);
    var writer = conn.writer(g.io, &.{});

    const config = RemoteClient.Config{
        .reader = &reader.interface,
        .writer = &writer.interface,
        .name = name,
    };
    var rc = try RemoteClient.init(g.allocator, config);
    defer rc.deinit(g.allocator);

    // Create a limited allocator here for catching incoming messages
    const buffer = try g.allocator.alloc(u8, 2000);
    defer g.allocator.free(buffer);
    var fb = std.heap.FixedBufferAllocator.init(buffer);

    var arena = std.heap.ArenaAllocator.init(fb.allocator());
    defer arena.deinit();

    // Wait for one EntryRequest to come in before letting loose with
    // the game

    rc.run(arena.allocator()) catch |err| {
        log.info("[{s}] Awaiting EntryRequest: {}", .{ name, err });
        return;
    };
    if (rc.getState() == .starting) {
        rc.setState(.connected);

        const id = try g.initPlayer(.{ .client = rc.client() });
        defer g.deinitPlayer(id);
        var player = g.getPlayer(id); // TODO: ugh

        player.addMessage("Welcome to the Dungeon of Doom!");
        g.addPlayer(player);

        // Feeds command gathering
        while (rc.getState() == .connected) {
            rc.run(arena.allocator()) catch |err| {
                log.info("[{s}] error: {}", .{ name, err });
                return;
            };
        }

        rc.writeDepart("Game Ending") catch {}; // Not much to do here
    }

    log.info("[{s}] End session", .{name});
}

fn server(g: *Game) void {
    var state: Game.State = .run;

    while (state != .end) {
        state = g.play();

        // TODO: ascend/descend requires proper map management within
        // the player context
    }
}

//
// Main
//

pub fn main(init: std.process.Init) !void {
    var config = Game.Config.init;
    config.setAllocator(init.gpa);
    config.setIo(init.io);

    var g: Game = undefined;
    g.init(config);
    defer g.deinit();

    try g.initLevel();
    defer g.deinitLevel();

    const s_thread = try std.Thread.spawn(.{}, server, .{&g});
    s_thread.detach();

    const addr = try net.IpAddress.parse("127.0.0.1", 0);
    var service = try addr.listen(init.io, .{ .reuse_address = true });
    defer service.deinit(init.io);

    log.info("[{}] Listening", .{service.socket.address.ip4.port});
    while (true) {
        var connection = try service.accept(init.io);
        errdefer connection.close(init.io);

        // FUTURE: thread pool, to throttle?  Async?

        const thread = try std.Thread.spawn(
            .{},
            handleClient,
            .{ &g, &connection },
        );
        thread.detach();
    }
}

// EOF
