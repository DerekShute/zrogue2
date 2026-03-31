//!
//! ncurses frontend, creating a Client from it
//!
//!
//! * (0,0) is top left corner,
//! * Y incrementing down the display,
//! * X incrementing right
//!
//! TODO: cursor management, mouse events
//!

const std = @import("std");
const NCurses = @import("ncurses");

const Client = @import("roguelib").Client;
const MapTile = @import("roguelib").MapTile;

const Self = @This();

//
// Types
//

pub const Config = struct {
    allocator: std.mem.Allocator,
    maxx: u8,
    maxy: u8,
};

//
// Service Routines
//

// Convert map location to what it is displayed as
fn mapToChar(ch: MapTile) u8 {
    // FUTURE: break out into types
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

fn renderChar(tile: Client.DisplayMapTile) u8 {
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

fn renderMap(self: *Self) void {
    // Row 0 is message line, last row (23) is stats, so map 0,0 is at
    // position 0,1

    if (self.c.displayChange()) |dc| { // if there's a change
        var _dc = dc;
        while (_dc.next()) |loc| {
            if (loc.getY() < self.c.y - 2) { // Reserve bottom display line
                self.setChar(
                    @intCast(loc.getX()),
                    @intCast(loc.getY() + 1),
                    renderChar(self.c.getTile(loc)),
                );
            }
        }
    }
}

//
// Members
//

c: Client = undefined,
curses: NCurses = undefined,
// Stats
purse: i32 = 0,
depth: i32 = 0,
// Message
messagebuf: [80]u8 = undefined, // TODO: size
message: []u8 = &.{},

//
// Utilities
//

fn readKeypress(self: *Self) NCurses.Keypress {
    return self.curses.readKeypress();
}

fn refresh(self: *Self) void {
    self.curses.refresh();
}

fn setChar(self: *Self, x: u16, y: u16, c: u8) void {
    self.curses.setChar(x, y, c);
}

fn setText(self: *Self, x: u16, y: u16, s: []const u8) void {
    self.curses.setText(x, y, s);
}

//
// Constructor / Destructor
//

pub fn init(config: Config) !Self {
    var curses = try NCurses.init();
    errdefer curses.deinit();

    const c: Client.Config = .{
        .allocator = config.allocator,
        .maxx = config.maxx,
        .maxy = config.maxy,
        .vtable = &.{
            .addMessage = cursesAddMessage,
            .getCommand = cursesGetCommand,
            .notifyDisplay = cursesNotifyDisplay,
            .setStatInt = cursesSetStatInt,
        },
    };

    return .{
        .c = try Client.init(c),
        .curses = curses,
    };
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.curses.deinit();
    self.c.deinit(allocator);
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
    const kp = self.readKeypress();

    return switch (kp) {
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
}

//
// Display Utility
//

fn displayHelp(self: *Self) void {
    // FIXME : This is horrible and adding to it is painful
    //         Multiline string constant with dividers, go line by line?

    self.setText(0, 0, "*                                                                              *");
    self.setText(0, 1, "         Welcome to the Dungeon of Doom          ");
    self.setText(0, 2, "                                                 ");
    self.setText(0, 3, " Use the arrow keys to move through the dungeon  ");
    self.setText(0, 4, " and collect gold.  You can only return to the   ");
    self.setText(0, 5, " surface after you have descended to the bottom. ");
    self.setText(0, 6, "                                                 ");
    self.setText(0, 7, " Commands include:                               ");
    self.setText(0, 8, "    ? - help (this)                              ");
    self.setText(0, 9, "    > - descend stairs (\">\")                     ");
    self.setText(0, 10, "    < - ascend stairs (\"<\")                      ");
    self.setText(0, 11, "    , - pick up gold  (\"$\")                      ");
    self.setText(0, 12, "    s - search for hidden doors                  ");
    self.setText(0, 13, "    q - chicken out and quit                     ");
    self.setText(0, 14, "                                                 ");
    self.setText(0, 15, " [type a command or any other key to continue]   ");
    self.setText(0, 16, "                                                 ");
    self.setText(0, 23, "*                                                                              *");
    self.refresh();
}

fn displayStatLine(self: *Self) void {
    // msg("Level: %d  Gold: %-5d  Hp: %*d(%*d)  Str: %2d(%d)  Arm: %-2d  Exp: %d/%ld  %s", ...)
    var buf: [80]u8 = undefined;

    const fmt = "Level: {}  Gold: {:<5}  Hp: some";
    const u_purse: u32 = @intCast(self.purse);
    const output = .{ self.depth, u_purse };

    @memset(buf[0..], ' ');
    // We know that error.NoSpaceLeft can't happen here
    _ = std.fmt.bufPrint(&buf, fmt, output) catch unreachable;
    self.setText(0, @intCast(self.c.y - 1), buf[0..]);
}

fn addMessage(self: *Self, msg: []const u8) void {
    @memset(self.messagebuf[0..80], ' ');
    self.message = &self.messagebuf;
    @memcpy(self.message[0..msg.len], msg);
    self.message = self.message[0..msg.len]; // Fix up the slice for length
}

fn displayMessage(self: *Self) void {
    var buf: [80]u8 = undefined;
    @memset(buf[0..], ' ');
    @memcpy(buf[0..], self.message);
    self.setText(0, 0, buf[0..]);
}

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

fn cursesGetCommand(ptr: *anyopaque) Client.Command {
    const self: *Self = @ptrCast(@alignCast(ptr));

    var cmd = self.readCommand();
    while (cmd == .help) {
        self.displayHelp();
        self.c.needRefresh();
        cmd = self.readCommand();
        // TODO: hit help a second time to rid menu
    }

    self.addMessage(" ");
    self.displayMessage();
    self.refresh();

    return cmd;
}

fn cursesNotifyDisplay(ptr: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.displayScreen();
}

fn cursesSetStatInt(ptr: *anyopaque, name: []const u8, value: i32) void {
    const self: *Self = @ptrCast(@alignCast(ptr));

    if (std.mem.eql(u8, "purse", name)) {
        self.purse = value;
    } else if (std.mem.eql(u8, "depth", name)) {
        self.depth = value;
    }

    self.displayStatLine();
    self.refresh();
}

//
// Unit Tests
//

// Avoid - this means dragging in ncurses to the test rig and cases where
// error generation botches the display

// EOF
