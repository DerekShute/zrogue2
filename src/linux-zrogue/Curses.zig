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
// Service Routines
//

fn renderMap(self: *Self) void {
    _ = self;

    // TODO: when you need to redisplay from scratch

    // Row 0 is message line, last row (23) is stats, so map 0,0 is at
    // position 0,1
}

//
// Members
//

c: Client = undefined,
ui: Rogue = undefined,

//
// Utilities
//

fn refresh(self: *Self) void {
    self.ui.displayRefresh();
}

fn setMapTile(self: *Self, x: u16, y: u16, tile: Client.DisplayTile) void {
    self.ui.setMapTile(x, y, tile);
}

fn setMessage(self: *Self, text: []const u8) void {
    self.ui.setMessage(text);
}

fn setStat(self: *Self, name: []const u8, value: i32) void {
    self.ui.setStat(name, value);
}

fn setText(self: *Self, x: u16, y: u16, s: []const u8) void {
    self.ui.setText(x, y, s);
}

//
// Constructor / Destructor
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

//
// Lifecycle
//

pub fn client(self: *Self) *Client {
    self.c.ptr = self;
    return &self.c;
}

//
// Input Utility
//

fn readCommand(self: *Self) Client.Command {
    return self.ui.readCommand();
}

//
// Display Utility
//

fn displayHelp(self: *Self) void {
    self.ui.displayHelp();
    self.refresh();
}

fn displayStatLine(self: *Self) void {
    self.ui.displayStatLine();
}

fn addMessage(self: *Self, msg: []const u8) void {
    self.ui.setMessage(msg);
}

fn displayMessage(self: *Self) void {
    self.ui.displayMessage();
}

// TODO: when you need to redisplay from scratch
fn displayScreen(self: *Self) void {
    //
    // Top line: messages
    //

    self.displayMessage();

    //
    // Bottom line: stat block
    //

    self.displayStatLine();

    //
    // Middle: the map
    //

    renderMap(self);

    // Regenerate display

    self.refresh();
}

//
// VTable Methods
//
// NotInitialized in here could be a panic instead of error return but
// the mock display also uses it to test for API correctness.

fn cursesAddMessage(ptr: *anyopaque, msg: []const u8) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.addMessage(msg);
    self.displayMessage();
    self.refresh();
}

fn cursesGetCommand(ptr: *anyopaque) !Client.Command {
    const self: *Self = @ptrCast(@alignCast(ptr));

    var cmd = self.readCommand();
    while (cmd == .help) { // TODO: if cmd==help ?
        self.displayHelp();
        // TODO: Refresh display
        cmd = self.readCommand();
        // TODO: hit help a second time to rid menu
    }

    self.addMessage(" ");
    self.displayMessage();
    self.refresh();

    return cmd;
}

fn cursesSetMapTile(ptr: *anyopaque, pos: Pos, tile: Client.DisplayTile) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.ui.setMapTile(@intCast(pos.getX()), @intCast(pos.getY()), tile);
    self.refresh();
}

fn cursesSetStatInt(ptr: *anyopaque, name: []const u8, value: i32) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.setStat(name, value);
    self.displayStatLine();
    self.refresh();
}

//
// Unit Tests
//

// Avoid - this means dragging in ncurses to the test rig and cases where
// error generation botches the display

// EOF
