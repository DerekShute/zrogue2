//!
//! ncurses frontend, creating a Client from it
//!
//!
//! * (0,0) is top left corner,
//! * Y incrementing down the display,
//! * X incrementing right
//!

const std = @import("std");

const Client = @import("roguelib").Client;
const Pos = @import("roguelib").Pos;
const Rogue = @import("rogueui").Rogue; // Presentation

const Self = @This();

//
// Members
//

c: Client = undefined,
ui: Rogue = undefined,

//
// Lifecycle
//

pub fn init() !Self {
    var ui = try Rogue.init();
    errdefer ui.deinit();

    const c: Client.Config = .{
        .vtable = &.{
            .addMessage = cursesAddMessage,
            .getCommand = cursesGetCommand,
            .setMapTile = cursesSetMapTile,
            .setStatInt = cursesSetStatInt,
        },
    };

    return .{
        .c = try Client.init(c),
        .ui = ui,
    };
}

pub fn deinit(self: *Self) void {
    self.ui.deinit();
}

pub fn client(self: *Self) *Client {
    self.c.ptr = self;
    return &self.c;
}

//
// Input Utility
//

//
// VTable Methods
//
// NotInitialized in here could be a panic instead of error return but
// the mock display also uses it to test for API correctness.

fn cursesAddMessage(ptr: *anyopaque, msg: []const u8) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.ui.setMessage(msg);
    self.ui.displayMessage();
    self.ui.displayRefresh();
}

fn cursesGetCommand(ptr: *anyopaque) !Client.Command {
    const self: *Self = @ptrCast(@alignCast(ptr));
    return self.ui.readCommand();
}

fn cursesSetMapTile(ptr: *anyopaque, pos: Pos, tile: Client.DisplayTile) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.ui.setMapTile(@intCast(pos.getX()), @intCast(pos.getY()), tile);
    self.ui.displayRefresh();
}

fn cursesSetStatInt(ptr: *anyopaque, name: []const u8, value: i32) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.ui.setStat(name, value);
    self.ui.displayStatLine();
    self.ui.displayRefresh();
}

//
// Unit Tests
//

// Avoid - this means dragging in ncurses to the test rig and cases where
// error generation botches the display

// EOF
