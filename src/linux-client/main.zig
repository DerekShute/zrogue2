//!
//! zrogue server CLI client
//!

const std = @import("std");
const Connector = @import("roguelib").Connector;
const NCurses = @import("ncurses");

const net = std.net;
const Allocator = std.mem.Allocator;
const Reader = std.io.Reader;
const Writer = std.io.Writer;

//
// Globals
//

var ending: bool = false;

// NCurses
var ncurses: NCurses = undefined;

// Stats
var purse: i32 = 0;
var depth: i32 = 0;

//
// NCurses minutia
//
// TODO: mutex!

fn refresh() void {
    ncurses.refresh();
}

fn setChar(x: u16, y: u16, c: u8) void {
    ncurses.setChar(x, y, c);
}

fn setText(x: u16, y: u16, s: []const u8) void {
    ncurses.setText(x, y, s);
}

fn readKeypress() NCurses.Keypress {
    return ncurses.readKeypress();
}

//
// Display service routines
//

fn mapToChar(ch: Connector.MapTile) u8 {
    const c: u8 = switch (ch) {
        .unknown => ' ',
        .floor => '.',
        .gold => '$',
        .wall => '#',
        .door => '+',
        .trap => '^',
        .player => '@',
        .stairs_down => '>',
        .stairs_up => '<',
    };
    return c;
}

fn renderChar(tile: Connector.Tile) u8 {
    if (tile.visible) {
        if (tile.entity != .unknown) {
            return mapToChar(tile.entity);
        }
        if (tile.item != .unknown) {
            return mapToChar(tile.item);
        }
        // Else floor
    } else { // Not visible
        // Client option: can use dimmed version of last known, etc
        if (!tile.floor.isFeature()) {
            return mapToChar(.unknown);
        }
    }

    return mapToChar(tile.floor);
}

fn displayMessageLine(message: []const u8) void {
    var buf: [80]u8 = undefined;
    @memcpy(buf[0..], message);
    @memset(buf[message.len..80], ' ');
    setText(0, 0, &buf);
}

fn displayStatLine() void {
    // msg("Level: %d  Gold: %-5d  Hp: %*d(%*d)  Str: %2d(%d)  Arm: %-2d  Exp: %d/%ld  %s", ...)
    var buf: [80]u8 = undefined;

    const fmt = "Level: {}  Gold: {:<5}  Hp: some";
    const u_purse: u32 = @intCast(purse);
    const output = .{ depth, u_purse };

    @memset(buf[0..], ' ');
    // We know that error.NoSpaceLeft can't happen here
    _ = std.fmt.bufPrint(&buf, fmt, output) catch unreachable;
    setText(0, 25, buf[0..]); // TODO line number
    refresh();
}

//
// Connector Interface
//

//
// TODO: note that this side shouldn't do curses actions.  It should post
// an update and let the main thread take care of it

fn depart(ctx: *anyopaque, text: []const u8) !void {
    _ = ctx;
    displayMessageLine(text);
    setText(0, 1, "--PRESS ANY KEY--");
    refresh();
    _ = readKeypress();
    ending = true;
}

fn updateMap(ctx: *anyopaque, x: i16, y: i16, tile: Connector.Tile) !void {
    _ = ctx;
    setChar(@intCast(x), @intCast(y + 1), renderChar(tile));
    refresh();
}

fn updateMessage(ctx: *anyopaque, text: []const u8) !void {
    _ = ctx;
    displayMessageLine(text);
    refresh();
}

fn updateTable(ctx: *anyopaque, table: []const u8, entry: []const u8, value: []const u8) !void {
    // TODO: ugh errors
    _ = ctx;
    const val: i16 = std.fmt.parseInt(i16, value, 10) catch return;

    // TODO: assuming table is "stats", and this should be generalized
    _ = table;

    if (std.mem.eql(u8, "purse", entry)) {
        purse = val;
    } else if (std.mem.eql(u8, "depth", entry)) {
        depth = val;
    }

    displayStatLine();
}

fn unsupported(ctx: *anyopaque) !void {
    _ = ctx;
    return error.Invalid;
}

//
// Input Loop
//

fn readCommand(connector: *Connector) !void {
    const kp = readKeypress();
    const cmd: Connector.Command = switch (kp) {
        .key_left => .go_west,
        .key_right => .go_east,
        .key_up => .go_north,
        .key_down => .go_south,
        @as(NCurses.Keypress, @enumFromInt('<')) => .ascend,
        @as(NCurses.Keypress, @enumFromInt('>')) => .descend,
        @as(NCurses.Keypress, @enumFromInt('?')) => .help,
        @as(NCurses.Keypress, @enumFromInt('q')) => .quit,
        @as(NCurses.Keypress, @enumFromInt('s')) => .search,
        @as(NCurses.Keypress, @enumFromInt(',')) => .take_item,
        else => .wait,
    };

    try connector.writeCommandMsg(cmd);
}

//
// Connection thread, for incoming messages
//

fn runConnection(connector: *Connector, allocator: Allocator) !void {
    while (true) {
        connector.run(allocator) catch |err| switch (err) {
            error.EndOfStream => return, // Probably shutting down
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

fn run_game(peer: net.Address) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const rbuf = try allocator.alloc(u8, 1000);
    errdefer allocator.free(rbuf);

    const stream = try net.tcpConnectToAddress(peer);
    defer stream.close();

    ncurses = try NCurses.init();
    defer ncurses.deinit();

    var reader = stream.reader(rbuf);
    var writer = stream.writer(&.{});

    var connector = Connector{
        .vt = &vt,
        // .ctx ignored do not reference
        .reader = reader.interface(),
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

    while (!ending) {
        try readCommand(&connector);
        displayMessageLine(" ");
        refresh();
    }
}

//
// MAIN
//

pub fn main() !void {
    var args = std.process.args();
    _ = args.skip(); // index 0 is the program name itself
    const port_value = args.next() orelse {
        std.debug.print("expect port as command line argument\n", .{});
        return;
    };

    const port = try std.fmt.parseInt(u16, port_value, 10);
    const peer = try net.Address.parseIp4("127.0.0.1", port);

    std.debug.print("Connecting to {f}\n", .{peer});

    run_game(peer) catch |err| if (!ending) {
        switch (err) {
            error.ConnectionRefused => std.debug.print("Error: Refused. No such server?\n", .{}),
            error.WriteFailed => std.debug.print("Error: Server down?\n", .{}),
            else => std.debug.print("Error {}\n", .{err}),
        }
        return;
    };

    std.debug.print("Disconnected from {f}\n", .{peer});
}
