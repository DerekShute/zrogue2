//!
//! Rogue presentation layer for ncurses
//!
//!
//! * (0,0) is top left corner,
//! * Y incrementing down the display,
//! * X incrementing right
//!

const std = @import("std");
const Command = @import("root.zig").Command;
const DisplayTile = @import("root.zig").DisplayTile;
const MapTile = @import("root.zig").MapTile;

const NCurses = @import("ncurses");
pub const Keypress = NCurses.Keypress;

const Self = @This();

// The traditional limits...

const XSIZE = 80;
const YSIZE = 24;

//
// Members
//

ncurses: NCurses = undefined,

// Stats
purse: i32 = 0,
depth: i32 = 0,

// Message
messagebuf: [XSIZE]u8 = undefined, // TODO: size
message: []u8 = &.{},

//
// Constructor / Destructor
//

pub fn init() !Self {
    var curses = try NCurses.init();
    errdefer curses.deinit();

    // TODO validate size

    return .{
        .ncurses = curses,
    };
}

pub fn deinit(self: *Self) void {
    self.ncurses.deinit();
}

//
// Utilities
//

fn mapToChar(ch: MapTile) u8 {
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

fn renderChar(tile: DisplayTile) u8 {
    const entity: MapTile = @enumFromInt(tile.entity);
    const floor: MapTile = @enumFromInt(tile.floor);
    const item: MapTile = @enumFromInt(tile.item);

    if (tile.visible) {
        if (entity != .unknown) {
            return mapToChar(entity);
        }
        if (item != .unknown) {
            return mapToChar(item);
        }
        // Else floor
    } else { // Not visible
        // Client option: can use dimmed version of last known, etc

        if (!floor.isFeature()) {
            return mapToChar(.unknown);
        }
    }

    return mapToChar(floor);
}

//
// Input Utility
//

pub fn readKeypress(self: *Self) NCurses.Keypress {
    return self.ncurses.readKeypress();
}

pub fn readCommand(self: *Self) Command {
    return switch (self.readKeypress()) {
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
// Content Updates
//

pub fn setMapTile(self: *Self, x: u16, y: u16, tile: DisplayTile) void {
    // Incoming x,y are map coordinates, not display
    //
    // Row 0 is message line, last row (23) is stats, so map 0,0 is at
    // position 0,1
    //
    // NOTE: this does alter the display!  Refresh it at your leisure!

    if ((x < XSIZE) and (y < YSIZE - 1)) {
        self.ncurses.setChar(x, y + 1, renderChar(tile));
    }
}

pub fn setMessage(self: *Self, msg: []const u8) void {
    @memset(self.messagebuf[0..XSIZE], ' '); // TODO slightly wasteful
    self.message = &self.messagebuf;
    @memcpy(self.message[0..msg.len], msg);
    self.message = self.message[0..msg.len]; // Fix up the slice for length
}

pub fn setStat(self: *Self, name: []const u8, value: i32) void {
    if (std.mem.eql(u8, "purse", name)) {
        self.purse = value;
    } else if (std.mem.eql(u8, "depth", name)) {
        self.depth = value;
    }
}

pub fn setText(self: *Self, x: u16, y: u16, s: []const u8) void {
    self.ncurses.setText(x, y, s);
}

//
// Help Menu
//

const help_text =
    \\*                                                                              *
    \\         Welcome to the Dungeon of Doom
    \\
    \\ Use the arrow keys to move through the dungeon
    \\ and collect gold.  You can only return to the
    \\ surface after you have descended to the bottom.
    \\
    \\ Commands include:
    \\    ? - help (this)
    \\    > - descend stairs (">")
    \\    < - ascend stairs ("<")
    \\    , - pick up gold  ("$")
    \\    s - search for hidden doors
    \\    q - chicken out and quit
    \\
    \\ [type a command or any other key to continue]
    \\
    \\*                                                                              *
;

pub fn displayHelp(self: *Self) void {
    var iter = std.mem.splitScalar(u8, help_text, '\n');
    var i: u16 = 0;

    const blank = [_]u8{' '} ** XSIZE;
    while (iter.next()) |line| {
        self.setText(0, i, &blank); // TODO: lame!
        self.setText(0, i, line);
        i = i + 1;
    }
    self.displayRefresh();
}

//
// Display
//

pub fn displayMessage(self: *Self) void {
    var buf: [XSIZE]u8 = undefined;
    @memset(buf[0..], ' '); // TODO: use buffer only?
    @memcpy(buf[0..], self.message);
    self.setText(0, 0, buf[0..]);
}

pub fn displayRefresh(self: *Self) void {
    self.ncurses.refresh();
}

// "Level: %d  Gold: %-5d  Hp: %*d(%*d)  Str: %2d(%d)  Arm: %-2d  Exp: %d/%ld  %s"
pub fn displayStatLine(self: *Self) void {
    var buf: [XSIZE]u8 = undefined;
    const fmt = "Level: {}  Gold: {:<5}  Hp: some";
    const u_purse: u32 = @intCast(self.purse);
    const output = .{ self.depth, u_purse };

    @memset(buf[0..], ' ');
    // We know that error.NoSpaceLeft can't happen here
    _ = std.fmt.bufPrint(&buf, fmt, output) catch unreachable;
    self.setText(0, YSIZE - 1, buf[0..]);
}

//
// Unit Tests
//

// EOF
