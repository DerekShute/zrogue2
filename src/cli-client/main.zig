//!
//! zrogue server line-output CLI client
//!
//! Clear prompt and output response data
//!
//! For very limited displays and useful debug
//!
//! NOTE: Glued to the hip of the rogue UI behavior
//!

const std = @import("std");

const Command = @import("common").Command;
const Connector = @import("connector");
const DisplayTile = @import("common").DisplayTile;
const MapTile = @import("common").MapTile;

const Allocator = std.mem.Allocator;
const log = std.log; // TODO: not thread safe
const net = std.Io.net;
const Reader = std.Io.Reader;
const Writer = std.Io.Writer;

// The traditional limits...
// FUTURE: from game

const XSIZE = 80;
const YSIZE = 24;

//
// Globals
//

var ending: bool = false;
var io: std.Io = undefined;
var stdout: *Writer = undefined;
var stdin: *Reader = undefined;

// Stats
var purse: i32 = 0;
var depth: i32 = 0;

// Message
var messagebuf: [XSIZE]u8 = undefined;
var message: []u8 = &.{};

// Map Display
// TODO: modified/reported bits
var map: [XSIZE * (YSIZE - 2)]u8 = undefined;

// Counts of things
var mapcount: u32 = 0;
var tilecount: u32 = 0;
var messagecount: u32 = 0;
var statcount: u32 = 0;

//
// Utilities
//

fn print(comptime fmt: []const u8, args: anytype) !void {
    // FUTURE: mutex
    try stdout.print(fmt, args);
    try stdout.flush();
}

fn sleep(duration: i64) !void {
    try io.sleep(std.Io.Duration.fromSeconds(duration), .real);
}

//
// Content Updates
//

fn mapToChar(tile: MapTile) u8 {
    return switch (tile) {
        .unknown => '_', // Different
        .floor => '.',
        .corridor => '.',
        .gold => '$',
        .wall => '#',
        .door => '+',
        .trap => '^',
        .player => '@',
        .stairs_down => '>',
        .stairs_up => '<',
    };
}

fn renderChar(tile: DisplayTile) u8 {
    const entity: MapTile = @enumFromInt(tile.entity);
    const floor: MapTile = @enumFromInt(tile.floor);
    const item: MapTile = @enumFromInt(tile.item);

    if (!tile.visible) {
        return '_';
    }
    if (entity != .unknown) {
        return mapToChar(entity);
    }
    if (item != .unknown) {
        return mapToChar(item);
    }
    return mapToChar(floor);
}

fn setMapTile(x: u16, y: u16, count: u8, tile: DisplayTile) void {
    for (0..count) |i| {
        const xidx: usize = @intCast(x);
        if ((xidx + i < XSIZE) and (y < YSIZE - 2)) {
            map[(xidx + i) + y * XSIZE] = renderChar(tile);
        }
    }
    mapcount = mapcount + 1;
    tilecount = tilecount + count;
}

pub fn setMessage(text: []const u8) void {
    @memset(messagebuf[0..XSIZE], ' ');
    message = &messagebuf;
    @memcpy(message[0..text.len], text);
    message = message[0..text.len]; // Fix up the slice for length

    messagecount = messagecount + 1;
}

pub fn setStat(name: []const u8, value: i32) void {
    if (std.mem.eql(u8, "purse", name)) {
        purse = value;
    } else if (std.mem.eql(u8, "depth", name)) {
        depth = value;
    }

    statcount = statcount + 1;
}

//
// Connector Interface
//

fn depart(ctx: *anyopaque, text: []const u8) !void {
    _ = ctx;
    print("Depart: {s}\n", .{text}) catch return error.Departing;
    ending = true;
    return error.Departing;
}

fn updateMap(ctx: *anyopaque, pos: [2]i16, count: u8, tile: Connector.DisplayTile) !void {
    _ = ctx;
    setMapTile(@intCast(pos[0]), @intCast(pos[1]), count, tile);
}

fn updateMessage(ctx: *anyopaque, text: []const u8) !void {
    _ = ctx;
    setMessage(text);
}

fn updateTable(ctx: *anyopaque, table: []const u8, entry: []const u8, value: []const u8) !void {
    _ = ctx;
    _ = table; // FUTURE eventually someone cares
    const val = std.fmt.parseInt(i16, value, 10) catch return error.Invalid;
    setStat(entry, val);
}

fn unsupported(ctx: *anyopaque) !void {
    _ = ctx;
    return error.Invalid;
}

//
// Command processing
//

fn doCommand(connector: *Connector, cmd: []u8) !void {
    const cmd_map = std.StaticStringMap(Command).initComptime(.{
        .{ "w", .go_west },
        .{ "e", .go_east },
        .{ "n", .go_north },
        .{ "s", .go_south },
        .{ "<", .ascend },
        .{ ">", .descend },
        .{ "q", .quit },
        .{ "S", .search },
        .{ ",", .take_item },
    });

    const command = cmd_map.get(cmd) orelse .wait;
    try print("command: {}\n", .{command});
    try connector.writeCommandMsg(@intFromEnum(command));
}

//
// Input/output loop from terminal
//

fn gameLoop(connector: *Connector) !void {
    // TODO: age out updates and messages

    while (!ending) {
        try sleep(1); // TODO: too long
        try print("map updates: {}:{}\n", .{ mapcount, tilecount });
        for (0..YSIZE - 2) |y| {
            for (0..XSIZE) |x| {
                const tile = map[x + y * XSIZE];
                try print("{c}", .{tile});
            }
            try print("\n", .{});
        }

        try print("message updates: {}\n", .{messagecount});
        try print(" * {s}\n", .{message});
        try print("stat updates: {}\n", .{statcount});
        try print(" * purse: {}\n", .{purse});
        try print(" * depth: {}\n", .{depth});
        mapcount = 0;
        messagecount = 0;
        statcount = 0;
        tilecount = 0;
        try print("Next? ", .{});

        const cmd = try stdin.takeDelimiterExclusive('\n');
        _ = try stdin.takeByte(); // Skip delimiter
        try doCommand(connector, cmd);
    }
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

fn run_game(peer: net.IpAddress, allocator: Allocator) !void {
    const rbuf = try allocator.alloc(u8, 1000);
    errdefer allocator.free(rbuf);

    const stream = try peer.connect(io, .{ .mode = .stream });
    defer stream.close(io);

    var reader = stream.reader(io, rbuf);
    var writer = stream.writer(io, &.{});
    var connector = Connector{
        .vt = &vt,
        // .ctx ignored do not reference
        .reader = &reader.interface,
        .writer = &writer.interface,
    };

    // TODO: explicit command
    try connector.writeEntryRequest("cli-client");

    const thread = try std.Thread.spawn(
        .{},
        runConnection,
        .{ &connector, allocator },
    );
    defer thread.join();

    try gameLoop(&connector);
}

//
// MAIN
//
// !void : errors get a stack trace and return value 1
//
pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();

    const args = try init.minimal.args.toSlice(arena);
    if (args.len < 2) {
        log.err("Expect port as command line argument", .{});
        return error.BadArgument;
    }
    const port = try std.fmt.parseInt(u16, args[1], 10);
    const peer = try net.IpAddress.parseIp4("127.0.0.1", port);

    var stdout_buf: [1024]u8 = undefined;
    var stdin_buf: [1024]u8 = undefined; // Woe if input overflows
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buf);
    var stdin_reader = std.Io.File.stdin().reader(init.io, &stdin_buf);
    stdout = &stdout_writer.interface;
    stdin = &stdin_reader.interface;
    io = init.io;

    try print("Connecting to {f}...", .{peer});

    run_game(peer, init.gpa) catch |err| if (!ending) {
        switch (err) {
            error.ConnectionRefused => log.err("Error: Refused. No such server?\n", .{}),
            error.WriteFailed => log.err("Error: Server down?\n", .{}),
            else => log.err("Error {}\n", .{err}),
        }
        return err;
    };

    try print("Disconnected from {f}...", .{peer});
}
