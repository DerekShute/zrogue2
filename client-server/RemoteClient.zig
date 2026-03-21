//!
//! Network-message Input/Display Client
//!
//! This is server side.
//!

const std = @import("std");
const server = @import("root.zig");

const Client = @import("roguelib").Client;
const Remote = @import("roguelib").Remote;

const Self = @This();

const log = std.log.scoped(.netclient);
const Reader = std.io.Reader;
const Writer = std.io.Writer;
const Allocator = std.mem.Allocator;

//
// Types
//

pub const Config = struct {
    allocator: std.mem.Allocator,
    reader: *Reader,
    writer: *Writer,
    name: []const u8, // TODO ugh
    maxx: u8 = 80,
    maxy: u8 = 24,
};

// Connection state
pub const State = enum {
    init,
    starting,
    connected,
    closing,
};

//
// Members
//

c: Client = undefined,
r: Remote = undefined,
name: []const u8 = undefined,
state: State = .init,

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
// Lifecycle
//

pub fn init(config: Config) !*Self {
    const allocator = config.allocator;
    const rc: *Self = try allocator.create(Self);
    errdefer allocator.destroy(rc);

    const pc: Client.Config = .{
        .allocator = config.allocator, // TODO does not manage, make explicit
        .maxx = config.maxx,
        .maxy = config.maxy,
        .vtable = &.{
            .getCommand = remoteGetCommand,
            .notifyDisplay = remoteNotifyDisplay,
            .setStatInt = remoteSetStatInt,
        },
    };

    rc.c = try Client.init(pc);
    errdefer rc.c.deinit(pc.allocator);
    rc.name = config.name;
    rc.r = Remote{
        .reader = config.reader,
        .writer = config.writer,
        .sm = &rig,
    };
    rc.r.ctx = rc;
    return rc;
}

pub fn deinit(self: *Self, allocator: Allocator) void {
    self.c.deinit(allocator);
    allocator.destroy(self);
}

pub fn client(self: *Self) *Client {
    self.c.ptr = self;
    return &self.c;
}

pub fn remote(self: *Self) *Remote {
    return &self.r;
}

//
// Formatting
//

pub fn format(self: Self, w: *Writer) Writer.Error!void {
    return w.print("{s}:{}", .{ self.name, self.state });
}

//
// Methods
//
// TODO: states are kind of game specific... Only for this module?

pub fn getState(self: *Self) State {
    return self.state;
}

pub fn setState(self: *Self, state: State) void {
    self.state = state;
}

// Run method processes messages; called with an arena
pub fn run(self: *Self, allocator: Allocator) void {
    self.r.run(allocator) catch |err| {
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
            try r_write(&self.r, msg);
        }
    };
}

fn writeMapUpdate(self: *Self, pos: []const i16, tile: server.MapUpdate.Tile) !void {
    const write = Wrap(server.MapUpdate, .map_update).write;
    write(self, .{ .x = pos[0], .y = pos[1], .tile = tile }) catch |err| {
        log.info("[{f}] Send error map-update {}", .{ self, err });
        return err;
    };
}

fn writeMessage(self: *@This(), text: []const u8) !void {
    const write = Wrap(server.Message, .message).write;
    write(self, .{ .message = text }) catch |err| {
        log.info("[{f}] Send error message {}", .{ self, err });
        return err;
    };
}

fn writeTableUpdate(self: *@This(), table: []const u8, entry: []const u8, value: []const u8) !void {
    const write = Wrap(server.TableUpdate, .table_update).write;
    try write(self, .{ .table = table, .entry = entry, .value = value });
}

//
// Client VTable callbacks
//

//
// TODO SERIOUS: need addMessage callback
//

fn remoteAddMessage(ptr: *anyopaque, text: []const u8) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.writeMessage(text) catch |err| {
        log.info("[{f}] remoteAddMessage {}", .{ self, err });
        self.setState(.closing);
    };
}

fn remoteGetCommand(ptr: *anyopaque) Client.Command {
    _ = ptr;
    //const self: *Self = @ptrCast(@alignCast(ptr));

    // NOCOMMIT: list gathered from remote, else wait or return none?
    return .wait;
}

fn remoteNotifyDisplay(ptr: *anyopaque) void {
    _ = ptr;
    //const self: *Self = @ptrCast(@alignCast(ptr));

    // NOCOMMIT: walk through and send X MapUpdate
}

fn remoteSetStatInt(ptr: *anyopaque, name: []const u8, value: i32) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    var buf: [80]u8 = undefined;

    const slice = std.fmt.bufPrint(&buf, "{}", .{value}) catch {
        // We know that error.NoSpaceLeft can't happen here
        unreachable;
    };
    self.writeTableUpdate("stats", name, slice) catch |err| {
        log.info("[{f}] remoteSetStatInt {}", .{ self, err });
        self.setState(.closing);
    };
}

//
// Remote callbacks from dispatch
//
// TODO SERIOUS: Not action message, Client.Command message!

fn doAction(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const msg: *server.ActionMsg = @ptrCast(@alignCast(ptr));

    if (self.getState() != .connected) {
        log.info("[{f}] ActionMsg in wrong state", .{self});
        return error.Failed;
    }

    log.info("[{f}] ActionMsg: {} {},{}", .{ self, msg.kind, msg.x, msg.y });
    // TODO: attach to list, or set to 'next' value
}

fn doDepart(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const msg: *server.Depart = @ptrCast(@alignCast(ptr));

    log.info("[{f}] Disconnecting: message '{s}'", .{ self, msg.message });
    self.setState(.closing);
}

fn doEntryRequest(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    errdefer self.setState(.closing);
    const msg: *server.EntryRequest = @ptrCast(@alignCast(ptr));

    if (self.getState() != .init) {
        log.info("[{f}] EntryRequest in wrong state", .{self});
        return error.Failed;
    }

    log.info("[{f}] Connecting: player '{s}'", .{ self, msg.name });
    self.setState(.starting);
}

fn doMapUpdate(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    _ = ptr; // Don't care, possibly pathological

    log.info("[{f}] Unexpected MapUpdate", .{self});
    return error.Failed;
}

fn doMessage(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    _ = ptr; // Don't care, possibly pathological

    log.info("[{f}] Unexpected Message", .{self});
    return error.Failed;
}

fn doTableUpdate(ctx: *anyopaque, ptr: *anyopaque) Remote.Error!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    _ = ptr;
    log.info("[{f}] Unexpected TableUpdate", .{self});
    return error.Failed;
}

// EOF
