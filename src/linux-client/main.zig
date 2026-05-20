//!
//! zrogue server CLI client
//!

const std = @import("std");
const Connector = @import("connector");
const UI = @import("ui");

const net = std.Io.net;
const Allocator = std.mem.Allocator;
const Reader = std.io.Reader;
const Writer = std.io.Writer;

//
// Globals
//

var ending: bool = false;
var ui: UI = undefined;

//
// NCurses minutia
//

fn displayMessage() void {
    ui.displayMessage();
}

fn displayStatLine() void {
    ui.displayStatLine();
}

fn refresh() void {
    ui.displayRefresh();
}

fn setMapTile(x: u16, y: u16, tile: Connector.DisplayTile) void {
    ui.setMapTile(x, y, tile);
}

fn setMessage(text: []const u8) void {
    ui.setMessage(text);
}

fn setStat(name: []const u8, value: i32) void {
    ui.setStat(name, value);
}

fn setText(x: u16, y: u16, s: []const u8) void {
    ui.setText(x, y, s);
}

//
// Connector Interface
//

//
// TODO: note that this side shouldn't do curses actions.  It should post
// an update and let the main thread take care of it

fn depart(ctx: *anyopaque, text: []const u8) !void {
    _ = ctx;
    setText(0, 0, text);
    setText(0, 1, "--PRESS ANY KEY--");
    refresh();
    ending = true;
    return error.Departing;
}

fn updateMap(ctx: *anyopaque, pos: [2]i16, tile: Connector.DisplayTile) !void {
    _ = ctx;
    setMapTile(@intCast(pos[0]), @intCast(pos[1]), tile);
    refresh(); // TODO: only care when waiting for command
}

fn updateMessage(ctx: *anyopaque, text: []const u8) !void {
    _ = ctx;
    setMessage(text);
    displayMessage();
    refresh();
}

fn updateTable(ctx: *anyopaque, table: []const u8, entry: []const u8, value: []const u8) !void {
    _ = ctx;
    _ = table; // FUTURE eventually someone cares
    const val = std.fmt.parseInt(i16, value, 10) catch return error.Invalid;
    setStat(entry, val);
    displayStatLine();
    refresh();
}

fn unsupported(ctx: *anyopaque) !void {
    _ = ctx;
    return error.Invalid;
}

//
// Input Loop
//

fn readCommand(connector: *Connector) !void {
    const cmd = ui.readCommand();
    try connector.writeCommandMsg(@intFromEnum(cmd));
}

//
// Connection thread, for incoming messages
//

fn runConnection(connector: *Connector, allocator: Allocator) !void {
    while (true) {
        connector.run(allocator) catch |err| switch (err) {
            error.EndOfStream => return, // Probably shutting down
            error.Departing => return,
            else => return err,
        };
    }
}

//
// Game loop
//

var vt = Connector.VTable{
    .depart = depart,
    .updateMap = updateMap,
    .updateMessage = updateMessage,
    .updateTable = updateTable,
    .unsupported = unsupported,
};

fn run_game(peer: net.IpAddress, allocator: Allocator, io: std.Io) !void {
    const rbuf = try allocator.alloc(u8, 1000);
    errdefer allocator.free(rbuf);

    const stream = try peer.connect(io, .{ .mode = .stream });
    defer stream.close(io);

    ui = try UI.init();
    defer ui.deinit();

    var reader = stream.reader(io, rbuf);
    var writer = stream.writer(io, &.{});

    var connector = Connector{
        .vt = &vt,
        // .ctx ignored do not reference
        .reader = &reader.interface,
        .writer = &writer.interface,
    };

    // TODO: player name

    try connector.writeEntryRequest("anonymous");

    const thread = try std.Thread.spawn(
        .{},
        runConnection,
        .{ &connector, allocator },
    );
    defer thread.join();

    displayStatLine();
    refresh();

    while (!ending) {
        try readCommand(&connector);
        setMessage(" ");
        displayMessage();
        refresh();
    }
}

//
// MAIN
//

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len < 2) {
        std.debug.print("expect port as command line argument\n", .{});
        return;
    }
    const port = try std.fmt.parseInt(u16, args[1], 10);
    const peer = try net.IpAddress.parseIp4("127.0.0.1", port);

    std.debug.print("Connecting to {f}\n", .{peer});

    run_game(peer, init.gpa, init.io) catch |err| if (!ending) {
        switch (err) {
            error.ConnectionRefused => std.debug.print("Error: Refused. No such server?\n", .{}),
            error.WriteFailed => std.debug.print("Error: Server down?\n", .{}),
            else => std.debug.print("Error {}\n", .{err}),
        }
        return;
    };

    std.debug.print("Disconnected from {f}\n", .{peer});
}
