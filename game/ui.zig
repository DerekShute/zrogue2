//!
//! Rogue presentation layer for ncurses
//!
//!
//! * (0,0) is top left corner,
//! * Y incrementing down the display,
//! * X incrementing right
//!

const std = @import("std");
const Command = @import("common").Command;
const DisplayTile = @import("common").DisplayTile;
const MapTile = @import("common").MapTile;

const NCurses = @import("ncurses");
pub const Keypress = NCurses.Keypress;

const Self = @This();

// The traditional limits...

const XSIZE = 80;
const YSIZE = 24;

//
// Members
//
// TODO: mutexes for protection

ncurses: NCurses = undefined,

// Stats
purse: i32 = 0,
depth: i32 = 0,

// Message
messagebuf: [XSIZE]u8 = undefined, // TODO: size
message: []u8 = &.{},

// Map Display
//
// Map is short 2 lines for lines of text

map: [XSIZE * (YSIZE - 2)]DisplayTile = undefined,

//
// Constructor / Destructor
//

pub fn init() !Self {
    var curses: NCurses = try NCurses.init();
    errdefer curses.deinit();

    // FUTURE: for now, must be at least.  This could be dynamic

    if (curses.getMaxX() < XSIZE) {
        return error.DisplayTooSmall;
    } else if (curses.getMaxY() < YSIZE) {
        return error.DisplayTooSmall;
    }

    var self: Self = .{
        .ncurses = curses,
    };

    for (0..YSIZE - 2) |y| {
        for (0..XSIZE) |x| {
            self.map[x + y * XSIZE] = .init;
        }
    }
    return self;
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

fn redrawMap(self: *Self) void {
    // TODO: slice iteration probably works better
    for (0..YSIZE - 2) |y| {
        for (0..XSIZE) |x| {
            const tile = self.map[x + y * XSIZE];
            self.ncurses.setChar(@intCast(x), @intCast(y + 1), renderChar(tile));
        }
    }
}

fn flushDisplay(self: *Self) void {
    self.ncurses.refresh();
}

fn getCommand(self: *Self) Command {
    return switch (self.ncurses.readKeypress()) {
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
// Input Utility
//

pub fn readCommand(self: *Self) Command {
    var did_help: bool = false;

    var cmd = self.getCommand();
    while (cmd == .help) {
        // Can now type your command with the help menu in sight
        // 'help' again to make display go away
        did_help = true;
        self.displayHelp();
        cmd = self.getCommand();
        if (cmd == .help) { // make menu go away, retry
            self.redraw();
            cmd = self.getCommand();
            did_help = false;
        }
    }

    // FUTURE: age message
    self.setMessage(" ");
    self.displayMessage();
    if (did_help) {
        self.redraw();
    } else {
        self.flushDisplay();
    }

    return cmd;
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
    //
    // TODO: display happens elsewhere

    if ((x < XSIZE) and (y < YSIZE - 2)) {
        if (!tile.visible) {
            self.map[x + y * XSIZE].visible = false;
        } else {
            self.map[x + y * XSIZE] = tile;
        }
        self.ncurses.setChar(x, y + 1, renderChar(self.map[x + y * XSIZE]));
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

fn displayHelp(self: *Self) void {
    var iter = std.mem.splitScalar(u8, help_text, '\n');
    var i: u16 = 0;

    const blank = [_]u8{' '} ** XSIZE;
    while (iter.next()) |line| {
        self.setText(0, i, &blank); // TODO: lame!
        self.setText(0, i, line);
        i = i + 1;
    }
    self.flushDisplay();
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
    self.flushDisplay();
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

// Fully refresh the display
pub fn redraw(self: *Self) void {
    self.displayMessage();
    self.displayStatLine();
    self.redrawMap();
    self.flushDisplay();
}

//
// Unit Tests
//

// EOF
