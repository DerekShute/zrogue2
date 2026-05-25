//!
//! Mock Input/Display provider for testing
//!

const std = @import("std");
const Client = @import("../Client.zig");
const Grid = @import("../grid.zig").Grid;
const Pos = @import("../Pos.zig");

const Self = @This();

//
// Types
//

const DisplayGrid = Grid(Client.DisplayTile);

//
// Members
//

c: Client = undefined,
next_command: ?Client.Command = null,
command_list: []Client.Command = &.{},
command_index: u16 = 0,

// TODO: this is game specific
purse: i32 = 0,
depth: i32 = 0,
messagebuf: [80]u8 = undefined, // TODO: size
message: []u8 = &.{},
dg: DisplayGrid = undefined,
map_updates: i32 = 0,

//
// Constructor / Destructor
//

pub fn init(allocator: std.mem.Allocator, x: usize, y: usize) !Self {
    const pc: Client.Config = .{
        .vtable = &.{
            .addMessage = mockAddMessage,
            .getCommand = mockGetCommand,
            .setMapTile = mockSetMapTile,
            .setStatInt = mockSetStatInt,
        },
    };

    const dg = try DisplayGrid.config(allocator, x, y);
    errdefer dg.deinit(allocator);

    var i = dg.iterator();
    while (i.next()) |t| {
        t.* = .init;
    }

    return .{
        .c = try Client.init(pc),
        .dg = dg,
    };
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.c.deinit();
    self.dg.deinit(allocator);
    return;
}

//
// Lifecycle
//

pub fn client(self: *Self) *Client {
    self.c.ptr = self;
    return &self.c;
}

//
// VTable
//

fn mockAddMessage(ptr: *anyopaque, msg: []const u8) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    // TODO: probably a better way to do this
    @memset(self.messagebuf[0..], ' ');
    self.message = &self.messagebuf;
    @memcpy(self.message[0..msg.len], msg);
    self.message = self.message[0..msg.len]; // Fix up the slice for length
}

fn mockGetCommand(ptr: *anyopaque) Client.Error!Client.Command {
    const self: *Self = @ptrCast(@alignCast(ptr));
    if (self.next_command) |cmd| {
        return cmd;
    }
    const i = self.command_index;
    if (i >= self.command_list.len) {
        @panic("No more mock commands to provide");
    }
    self.command_index += 1;
    return self.command_list[i];
}

fn mockSetMapTile(ptr: *anyopaque, pos: Pos, count: u8, tile: Client.DisplayTile) void {
    _ = count; // TODO
    const self: *Self = @ptrCast(@alignCast(ptr));
    // std.debug.print("set tile {}/{} to {}\n", .{ x, y, tile });
    const dt = self.dg.find(
        @intCast(pos.getX()),
        @intCast(pos.getY()),
    ) catch @panic("mockSetMapTile error");
    dt.* = tile;
    self.map_updates += 1;
}

fn mockSetStatInt(ptr: *anyopaque, name: []const u8, value: i32) void {
    const self: *Self = @ptrCast(@alignCast(ptr));

    if (std.mem.eql(u8, "purse", name)) {
        self.purse = value;
    } else if (std.mem.eql(u8, "depth", name)) {
        self.depth = value;
    } else {
        @panic("mockSetStatInt: Unsupported name");
    }
}

//
// Methods for testing convenience
//

pub fn setCommandList(self: *Self, list: []Client.Command) void {
    self.next_command = null;
    self.command_list = list;
    self.command_index = 0;
}

pub fn setCommand(self: *Self, cmd: Client.Command) void {
    self.next_command = cmd;
}

pub fn getTile(self: *Self, x: i16, y: i16) !Client.DisplayTile {
    const dt = try self.dg.find(@intCast(x), @intCast(y));
    return dt.*;
}

pub fn getStatPurse(self: *Self) i32 {
    return self.purse;
}

pub fn getStatDepth(self: *Self) i32 {
    return self.depth;
}

pub fn getMessage(self: *Self) []const u8 {
    return self.message;
}

pub fn getMapUpdates(self: *Self) i32 {
    // Resets count
    const ret = self.map_updates;
    self.map_updates = 0;
    return ret;
}

//
// Unit tests
//

const expect = std.testing.expect;
const expectError = std.testing.expectError;

var testlist = [_]Client.Command{
    .go_west,
    .quit,
};

test "try out mock" {
    var m = try init(std.testing.allocator, 20, 20);
    defer m.deinit(std.testing.allocator);

    var c = m.client();
    m.setCommand(.go_west);
    try expect(try c.getCommand() == .go_west);
    try expect(try c.getCommand() == .go_west);
    m.setCommand(.go_east);
    try expect(try c.getCommand() == .go_east);

    try expect(m.getStatPurse() == 0);
    try expect(m.getStatDepth() == 0);

    c.setStatInt("purse", 10);
    try expect(m.getStatPurse() == 10);
    c.setStatInt("depth", 4);
    try expect(m.getStatDepth() == 4);
}

test "try out list" {
    var m = try init(std.testing.allocator, 20, 20);
    defer m.deinit(std.testing.allocator);
    var c = m.client();

    m.setCommandList(&testlist);
    try expect(try c.getCommand() == .go_west);
    try expect(try c.getCommand() == .quit);
}

// EOF
