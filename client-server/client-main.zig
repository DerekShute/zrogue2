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

//
// Service wrapper
//

const Service = struct {
    ncurses: NCurses = undefined,
    remote: Remote = undefined,
    peer: net.Address = undefined,
    // Stats
    purse: i32 = 0,
    depth: i32 = 0,

    const Self = @This();

    //
    // Message write wrappers
    //

    fn Wrap(comptime T: type, comptime MT: server.MessageType) type {
        // It's just wrappers all the way down.  This just simplifies the
        // invocation in the write declaration
        return struct {
            pub fn write(self: *Self, msg: T) !void {
                const r_write = Remote.Write(T, @intFromEnum(MT)).write;
                try r_write(&self.remote, msg);
            }
        };
    }

    pub fn writeEntryRequest(self: *Self, text: []const u8) !void {
        const write = Wrap(server.EntryRequest, .entry_request).write;
        try write(self, .{ .name = text });
    }

    pub fn writeAction(self: *Self, kind: server.ActionMsg.Type, pos: []const i16) !void {
        const write = Wrap(server.ActionMsg, .action).write;
        try write(self, .{ .kind = kind, .x = pos[0], .y = pos[1] });
    }

    pub fn writeDepart(self: *Self, text: []const u8) !void {
        const write = Wrap(server.Depart, .depart).write;
        try write(self, .{ .message = text });
    }

    pub fn run(self: *Self, allocator: Allocator) !void {
        try self.remote.run(allocator);
    }

    // NCurses service routines

    fn refresh(self: *Self) void {
        self.ncurses.refresh();
    }

    fn setChar(self: *Self, x: u16, y: u16, c: u8) void {
        self.ncurses.setChar(x, y, c);
    }

    fn setText(self: *Self, x: u16, y: u16, s: []const u8) void {
        self.ncurses.setText(x, y, s);
    }
};

//
// Service routines
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

fn displayMessageLine(service: *Service, message: []const u8) void {
    var buf: [80]u8 = undefined;

    // TODO not great, should store messages here, not in Client

    @memset(buf[0..], ' ');
    // We know that error.NoSpaceLeft can't happen here
    _ = std.fmt.bufPrint(&buf, "{s}", .{message}) catch unreachable;
    service.setText(0, 0, buf[0..]);
    service.refresh();
}

fn displayStatLine(service: *Service) void {
    // msg("Level: %d  Gold: %-5d  Hp: %*d(%*d)  Str: %2d(%d)  Arm: %-2d  Exp: %d/%ld  %s", ...)
    var buf: [80]u8 = undefined;

    const fmt = "Level: {}  Gold: {:<5}  Hp: some";
    const u_purse: u32 = @intCast(service.purse);
    const output = .{ service.depth, u_purse };

    @memset(buf[0..], ' ');
    // We know that error.NoSpaceLeft can't happen here
    _ = std.fmt.bufPrint(&buf, fmt, output) catch unreachable;
    service.setText(0, 25, buf[0..]); // TODO line number
    service.refresh();
}

//
// State machine callbacks
//

fn doAction(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    _ = ctx;
    _ = ptr;
    return error.Failed;
}

fn doCommand(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    _ = ctx;
    _ = ptr;
    return error.Failed;
}

fn doDepart(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    _ = ctx;
    _ = ptr;
    return error.Failed; // TODO: elegance
}

fn doEntryRequest(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    _ = ctx;
    _ = ptr;
    return error.Failed;
}

//
// Valid messages
//

fn doMapUpdate(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    const service: *Service = @ptrCast(@alignCast(ctx));
    const msg: *server.MapUpdate = @ptrCast(@alignCast(ptr));

    service.setChar(
        @intCast(msg.x),
        @intCast(msg.y + 1),
        renderChar(msg.tile),
    );
    service.refresh();
}

fn doMessage(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    const service: *Service = @ptrCast(@alignCast(ctx));
    const msg: *server.Message = @ptrCast(@alignCast(ptr));
    displayMessageLine(service, msg.message);
}

fn doTableUpdate(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    const service: *Service = @ptrCast(@alignCast(ctx));
    const msg: *server.TableUpdate = @ptrCast(@alignCast(ptr));
    const val: i16 = std.fmt.parseInt(i16, msg.value, 10) catch return error.Failed;

    // TODO: assuming table is "stats"

    if (std.mem.eql(u8, "purse", msg.entry)) {
        service.purse = val;
    } else if (std.mem.eql(u8, "depth", msg.entry)) {
        service.depth = val;
    }

    displayStatLine(service);
}

//
// Dispatch table for server run
//
const fns = [_]Remote.ReadFn{
    doAction,
    doCommand,
    doDepart,
    doEntryRequest,
    doMapUpdate,
    doMessage,
    doTableUpdate,
};
const rig = server.genDispatch(fns);

//
// Main
//

fn run_game(peer: net.Address) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const stream = try net.tcpConnectToAddress(peer);
    defer stream.close();

    const rbuf = try allocator.alloc(u8, 1000);
    errdefer allocator.free(rbuf);

    var reader = stream.reader(rbuf);
    var writer = stream.writer(&.{});

    var curses = try NCurses.init();
    defer curses.deinit();

    var service = Service{
        .ncurses = curses,
        .peer = peer,
        .remote = Remote{
            .reader = reader.interface(),
            .writer = &writer.interface,
            .sm = &rig,
        },
    };
    service.remote.ctx = &service;

    // TODO handle errors
    // TODO player name
    try service.writeEntryRequest("anonymous");

    while (true) {
        try service.run(allocator);
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

    run_game(peer) catch {};

    std.debug.print("Disconnected from {f}\n", .{peer});
}
