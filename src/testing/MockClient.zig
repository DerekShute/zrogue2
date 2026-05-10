//!
//! Mock Input/Display provider for testing
//!

const std = @import("std");
const Client = @import("roguelib").Client;

const Self = @This();

//
// Types
//

pub const Config = struct {
    commands: []Client.Command,
};

//
// Members
//

c: Client = undefined,
command_list: []Client.Command = undefined,
command_index: u16 = 0,
notified: bool = false,

purse: i32 = 0,
depth: i32 = 0,
messagebuf: [80]u8 = undefined, // TODO: size
message: []u8 = &.{},

//
// Constructor / Destructor
//

pub fn init(config: Config) !Self {
    const pc: Client.Config = .{
        .vtable = &.{
            .addMessage = mockAddMessage,
            .getCommand = mockGetCommand,
            .notifyDisplay = mockNotifyDisplay,
            .setMapTile = mockSetMapTile,
            .setStatInt = mockSetStatInt,
        },
    };

    return .{
        .c = try Client.init(pc),
        .command_list = config.commands,
    };
}

pub fn deinit(self: *Self) void {
    self.c.deinit();
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
    const i = self.command_index;
    if (i >= self.command_list.len) {
        @panic("No more mock commands to provide");
    }
    self.command_index += 1;
    return self.command_list[i];
}

fn mockNotifyDisplay(ptr: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.notified = true;
}

fn mockSetMapTile(ptr: *anyopaque, x: u16, y: u16, tile: Client.DisplayTile) void {
    // NOCOMMIT
    _ = ptr;
    _ = x;
    _ = y;
    _ = tile;
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

pub fn getStatPurse(self: *Self) i32 {
    return self.purse;
}

pub fn getStatDepth(self: *Self) i32 {
    return self.depth;
}

pub fn getNotified(self: *Self) bool {
    // Turns itself off for your convenience
    const was = self.notified;
    self.notified = false;
    return was;
}

pub fn getMessage(self: *Self) []const u8 {
    return self.message;
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
    var m = try init(.{
        .commands = &testlist,
    });
    defer m.deinit();

    var c = m.client();
    try expect(try c.getCommand() == .go_west);

    try expect(m.getStatPurse() == 0);
    try expect(m.getStatDepth() == 0);
    try expect(!m.getNotified());

    c.setStatInt("purse", 10);
    try expect(m.getStatPurse() == 10);
    c.setStatInt("depth", 4);
    try expect(m.getStatDepth() == 4);
}

// EOF
