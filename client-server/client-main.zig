//!
//! zrogue server CLI client
//!

const std = @import("std");
const server = @import("root.zig");
const NCurses = @import("ncurses");

const net = std.net;
const Allocator = std.mem.Allocator;
const Reader = std.io.Reader;
const Writer = std.io.Writer;

const Remote = server.Remote;

const Connector = @import("Connector.zig");

//
// Globals
//

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

fn mapToChar(ch: server.MapUpdate.MapTile) u8 {
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

fn renderChar(tile: server.MapUpdate.Tile) u8 {
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
    refresh();
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

fn updateMap(x: i16, y: i16, tile: server.MapUpdate.Tile) void {
    setChar(@intCast(x), @intCast(y + 1), renderChar(tile));
    refresh();
}

fn updateMessage(text: []const u8) void {
    displayMessageLine(text);
}

fn updateTable(table: []const u8, entry: []const u8, value: []const u8) void {
    // TODO: ugh errors
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

var vt = Connector.VTable{
    .updateMap = updateMap,
    .updateMessage = updateMessage,
    .updateTable = updateTable,
};

//
// Main
//

fn readCommand(connector: *Connector) !void {
    const kp = readKeypress();
    const command: server.CommandMsg.Command = switch (kp) {
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

    try connector.writeCommandMsg(command);
}

fn runConnector(connect: *Connector, allocator: Allocator) !void {
    try connect.run(allocator);
}

fn run_game(peer: net.Address) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const stream = try net.tcpConnectToAddress(peer);
    defer stream.close();

    const rbuf = try allocator.alloc(u8, 1000);
    errdefer allocator.free(rbuf);

    var reader = stream.reader(rbuf);
    var writer = stream.writer(&.{});

    var connect = Connector{
        .vt = &vt,
        .peer = peer,
        .remote = Remote{
            .reader = reader.interface(),
            .writer = &writer.interface,
        },
    };

    const thread = try std.Thread.spawn(
        .{},
        runConnector,
        .{ &connect, allocator },
    );
    thread.detach();

    // TODO error checking etc
    while (true) {
        try readCommand(&connect);
        displayMessageLine(" ");
    }
}

pub fn main() !void {
    // TODO: better

    var args = std.process.args();
    // The first (0 index) Argument is the path to the program.
    _ = args.skip();
    const port_value = args.next() orelse {
        std.debug.print("expect port as command line argument\n", .{});
        return error.NoPort;
    };

    const port = try std.fmt.parseInt(u16, port_value, 10);
    const peer = try net.Address.parseIp4("127.0.0.1", port);

    std.debug.print("Connecting to {f}\n", .{peer});

    ncurses = try NCurses.init();
    defer ncurses.deinit();

    run_game(peer) catch {};

    std.debug.print("Disconnected from {f}\n", .{peer});
}
