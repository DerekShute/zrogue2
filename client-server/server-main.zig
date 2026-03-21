//!
//! Linux cli-based server
//!

const std = @import("std");
const server = @import("root.zig");

const Allocator = std.mem.Allocator;
const Reader = std.io.Reader;
const Writer = std.io.Writer;

const log = std.log.scoped(.server);
const net = std.net;

const Remote = server.Remote;

// TODO: expanding to its own thing
const Service = struct {
    remote: Remote = undefined,
    // TODO game
    name: []const u8 = undefined,
    state: Remote.State = .init, // TODO kind of gross

    const Self = @This();

    pub fn setState(self: *Self, state: Remote.State) void {
        self.state = state;
    }

    pub fn getState(self: *Self) Remote.State {
        return self.state;
    }

    pub fn format(self: Self, w: *Writer) Writer.Error!void {
        return w.print("{s}:{}", .{ self.name, self.state });
    }

    pub fn run(self: *Self, allocator: Allocator) void {
        self.remote.run(allocator) catch |err| {
            log.info("[{f}] error {}", .{ self, err });
            self.setState(.closing);
        };
    }

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

    pub fn writeMapUpdate(self: *Self, pos: []const i16, tile: server.MapUpdate.Tile) !void {
        const write = Wrap(server.MapUpdate, .map_update).write;
        write(self, .{ .x = pos[0], .y = pos[1], .tile = tile }) catch |err| {
            log.info("[{f}] Send error map-update {}", .{ self, err });
            return err;
        };
    }

    pub fn writeMessage(self: *@This(), text: []const u8) !void {
        const write = Wrap(server.Message, .message).write;
        write(self, .{ .message = text }) catch |err| {
            log.info("[{f}] Send error message {}", .{ self, err });
            return err;
        };
    }

    pub fn writeTableUpdate(self: *@This(), table: []const u8, entry: []const u8, value: []const u8) !void {
        const write = Wrap(server.TableUpdate, .table_update).write;
        write(self, .{ .table = table, .entry = entry, .value = value }) catch |err| {
            log.info("[{f}] Send error table-update {}", .{ self, err });
            return err;
        };
    }
};

//
// State machine callbacks
//

fn doAction(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    const self: *Service = @ptrCast(@alignCast(ctx));
    const msg: *server.ActionMsg = @ptrCast(@alignCast(ptr));

    if (self.getState() != .connected) {
        log.info("[{f}] ActionMsg in wrong state", .{self});
        self.setState(.closing);
        return;
    }
    log.info("[{f}] Action: {} {},{}", .{ self, msg.kind, msg.x, msg.y });
}

fn doDepart(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    const self: *Service = @ptrCast(@alignCast(ctx));
    const msg: *server.Depart = @ptrCast(@alignCast(ptr));

    log.info("[{f}] Disconnecting: message '{s}'", .{ self, msg.message });
    self.setState(.closing);
}

fn doEntryRequest(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    const self: *Service = @ptrCast(@alignCast(ctx));
    errdefer self.setState(.closing);
    const msg: *server.EntryRequest = @ptrCast(@alignCast(ptr));

    if (self.getState() != .init) {
        log.info("[{f}] EntryRequest in wrong state", .{self});
        return;
    }

    log.info("[{f}] Connected: player '{s}'", .{ self, msg.name });
    self.setState(.connected);

    self.writeMessage("Welcome to the Dungeon of Doom!") catch return error.Failed;

    const tile = server.MapUpdate.Tile{
        .entity = .unknown,
        .item = .gold,
        .floor = .wall,
        .visible = true,
    };
    self.writeMapUpdate(&.{ 0, 1 }, tile) catch return error.Failed;
    self.writeTableUpdate("stats", "purse", "0") catch return error.Failed;
}

fn doMapUpdate(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    const self: *Service = @ptrCast(@alignCast(ctx));
    _ = ptr; // Don't care, possibly pathological

    log.info("[{f}] Unexpected map update", .{self});
    self.setState(.closing);
}

fn doMessage(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    const self: *Service = @ptrCast(@alignCast(ctx));
    _ = ptr; // Don't care, possibly pathological

    log.info("[{f}] Unexpected message", .{self});
    self.setState(.closing);
}

fn doTableUpdate(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    const self: *Service = @ptrCast(@alignCast(ctx));
    _ = ptr;
    log.info("[{f}] Unexpected table update", .{self});
    self.setState(.closing);
}

//
// Dispatch table for server run
//
const fns = [_]Remote.ReadFn{
    doAction,
    doDepart,
    doEntryRequest,
    doMapUpdate,
    doMessage,
    doTableUpdate,
};
const rig = server.genDispatch(fns);

//
// Client connection
//

fn handleClient(conn: *net.Server.Connection, allocator: Allocator) !void {
    const name = try std.fmt.allocPrint(allocator, "{f}", .{conn.address});
    defer allocator.free(name);

    log.info("[{s}] Accepted connection", .{name});

    const rbuf = try allocator.alloc(u8, 1024);
    defer allocator.free(rbuf);
    var reader = conn.stream.reader(rbuf);
    var writer = conn.stream.writer(&.{});

    // TODO: Create connection to Game but nothing happens and no step
    // forward until state aligns

    var service = Service{
        .name = name,
        .remote = Remote{
            .reader = reader.interface(),
            .writer = &writer.interface,
            .sm = &rig,
        },
    };
    service.remote.ctx = &service;

    //
    // Create a limited allocator here for catching incoming messages
    //
    const buffer = try allocator.alloc(u8, 2000);
    defer allocator.free(buffer);
    var fb = std.heap.FixedBufferAllocator.init(buffer);

    var arena = std.heap.ArenaAllocator.init(fb.allocator());
    defer arena.deinit();

    while (service.getState() != .closing) {
        service.run(arena.allocator());
    }

    log.info("[{s}] End session", .{name});
}

//
// Main
//

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const loopback = try net.Ip4Address.parse("127.0.0.1", 0);
    const localhost = net.Address{ .in = loopback };
    var service = try localhost.listen(.{
        .reuse_address = true,
    });
    defer service.deinit();

    log.info("[{}] Listening", .{service.listen_address.getPort()});
    while (true) {
        var connection = try service.accept();
        defer connection.stream.close();

        try handleClient(&connection, gpa.allocator());
    }
}

// EOF
