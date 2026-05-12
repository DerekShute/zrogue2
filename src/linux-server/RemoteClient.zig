//!
//! Network-message Input/Display Client
//!
//! This is server side.
//!

const std = @import("std");

const Client = @import("roguelib").Client;
const Connector = @import("connector");

const Self = @This();

const log = std.log.scoped(.netclient);
const Reader = std.Io.Reader;
const Writer = std.Io.Writer;
const Allocator = std.mem.Allocator;

//
// Types
//

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

allocator: Allocator = undefined,
c: Client = undefined,
connector: Connector = undefined,
name: []const u8 = undefined,
next_command: ?Client.Command = null,
state: State = .init,

//
// Lifecycle
//

pub const Config = struct {
    reader: *Reader,
    writer: *Writer,
    name: []const u8, // TODO ugh
};

pub fn init(allocator: Allocator, config: Config) !*Self {
    const rc: *Self = try allocator.create(Self);
    errdefer allocator.destroy(rc);

    const pc: Client.Config = .{
        .vtable = &.{
            .addMessage = remoteAddMessage,
            .getCommand = remoteGetCommand,
            .setMapTile = remoteSetMapTile,
            .setStatInt = remoteSetStatInt,
        },
    };

    rc.allocator = allocator;
    rc.c = try Client.init(pc);
    errdefer rc.c.deinit(allocator);
    rc.name = config.name;
    rc.connector = Connector{
        .vt = &vt,
        .reader = config.reader,
        .writer = config.writer,
    };
    rc.connector.ctx = rc;
    rc.state = .init;

    return rc;
}

pub fn deinit(self: *Self, allocator: Allocator) void {
    self.c.deinit();
    allocator.destroy(self);
}

pub fn client(self: *Self) *Client {
    self.c.ptr = self;
    return &self.c;
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

pub fn getState(self: *Self) State {
    return self.state;
}

pub fn setState(self: *Self, state: State) void {
    self.state = state;
}

// Run method processes messages; called with an arena
pub fn run(self: *Self, allocator: Allocator) !void {
    self.connector.run(allocator) catch |err| {
        self.setState(.closing);
        return err;
    };
}

pub fn writeDepart(self: *Self, text: []const u8) !void {
    try self.connector.writeDepart(text);
}

//
// Client VTable callbacks
//

fn remoteAddMessage(ptr: *anyopaque, text: []const u8) void {
    const self: *Self = @ptrCast(@alignCast(ptr));

    if (self.state != .connected) { // Prevent flood of failures
        return;
    }

    self.connector.writeMessage(text) catch |err| {
        log.info("[{f}] remoteAddMessage {}", .{ self, err });
        self.setState(.closing);
    };
}

fn remoteGetCommand(ptr: *anyopaque) !Client.Command {
    const self: *Self = @ptrCast(@alignCast(ptr));

    if (self.state != .connected) { // Prevent flood of failures
        return .wait; // TODO: no error path here
    }

    self.run(self.allocator) catch return error.ProviderError;

    if (self.next_command) |cmd| {
        self.next_command = null;
        return cmd;
    }
    return .wait; // TODO need optionalreturn or something
}

fn remoteSetMapTile(ptr: *anyopaque, x: u16, y: u16, tile: Client.DisplayTile) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    var spot: [2]i16 = .{ @intCast(x), @intCast(y) }; // TODO Increasingly stupid

    if (self.state != .connected) { // Prevent flood of failures
        return;
    }

    self.connector.writeMapUpdate(&spot, tile) catch |err| {
        log.info("[{f}] remoteSetMapTile {}", .{ self, err });
        self.setState(.closing);
        return; // TODO no error return is a problem
    };
}

fn remoteSetStatInt(ptr: *anyopaque, name: []const u8, value: i32) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    var buf: [80]u8 = undefined;

    if (self.state != .connected) { // Prevent flood of failures
        return;
    }

    const slice = std.fmt.bufPrint(&buf, "{}", .{value}) catch {
        // We know that error.NoSpaceLeft can't happen here
        unreachable;
    };
    self.connector.writeTableUpdate("stats", name, slice) catch |err| {
        log.info("[{f}] remoteSetStatInt {}", .{ self, err });
        self.setState(.closing);
    };
}

//
// Remote callbacks from dispatch
//

fn command(ctx: *anyopaque, cmd: u16) !void {
    const self: *Self = @ptrCast(@alignCast(ctx));

    // log.info("[{f}] CommandMsg: {}", .{ self, msg.c });

    if (self.getState() != .connected) {
        log.info("[{f}] CommandMsg in wrong state", .{self});
        return error.Invalid;
    }

    self.next_command = @enumFromInt(cmd);
}

fn depart(ctx: *anyopaque, text: []const u8) !void {
    const self: *Self = @ptrCast(@alignCast(ctx));

    log.info("[{f}] Depart: message '{s}'", .{ self, text });
    return error.Departing;
}

fn entryRequest(ctx: *anyopaque, name: []const u8) !void {
    const self: *Self = @ptrCast(@alignCast(ctx));

    if (self.getState() != .init) {
        log.info("[{f}] EntryRequest in wrong state", .{self});
        return error.Invalid;
    }

    log.info("[{f}] Connecting: player '{s}'", .{ self, name });
    self.setState(.starting);
}

fn unsupported(ctx: *anyopaque) !void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    log.info("[{f}] Invalid message", .{self});
    return error.Invalid;
}

var vt = Connector.VTable{
    .command = command,
    .depart = depart,
    .entry = entryRequest,
    .unsupported = unsupported,
};

// EOF
