//!
//! ncurses frontend
//!
//! * (0,0) is top left corner,
//! * Y incrementing down the display,
//! * X incrementing right
//!
//! FUTURE: mouse events
//! FUTURE: resize events, flexible sizing
//!

const std = @import("std");
const curses = @cImport(@cInclude("curses.h"));
const Command = @import("rogueui").Command;
const MapTile = @import("rogueui").MapTile;
const DisplayTile = @import("rogueui").DisplayTile;

const Self = @This();

const min_x = 80;
const min_y = 24;

//
// Types
//

pub const Keypress = enum(u8) {
    key_left,
    key_right,
    key_up,
    key_down,
    _,
};

//
// Members
//

win: *curses.WINDOW = undefined,

//
// Services
//

fn paranoia(res: c_int) c_int {
    if (res == curses.ERR) {
        unreachable; // Really don't expect this
    }
    return res;
}

fn paranoiaVoid(res: c_int) void {
    if (res == curses.ERR) {
        unreachable; // Really don't expect this
    }
}

//
// Lifecycle
//

pub fn init() !Self {
    // Note technically can fail
    const w = curses.initscr(); // null return not defined
    errdefer {
        _ = curses.endwin(); // error only if window uninitialized.
    }

    if (w == null) {
        unreachable;
    }
    // Instantly process events, and activate arrow keys

    // raw/keypad/noecho: no defined error cases
    paranoiaVoid(curses.raw());
    paranoiaVoid(curses.keypad(w.?, true));
    paranoiaVoid(curses.noecho());
    // curs_set: ERR only if argument value is unsupported
    paranoiaVoid(curses.curs_set(0));

    // getmaxx/getmaxy ERR iff null window parameter
    const display_maxx = paranoia(curses.getmaxx(w.?));
    const display_maxy = paranoia(curses.getmaxy(w.?));

    if ((display_maxx < min_x) or (display_maxy < min_y)) {
        return error.DisplayTooSmall;
    }

    return .{
        .win = w.?,
    };
}

pub fn deinit(self: *Self) void {
    _ = self; // interface consistency
    _ = curses.endwin();
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

//
// Methods
//

pub fn readCommand(self: *Self) Command {
    _ = self;
    return switch (paranoia(curses.getch())) {
        curses.KEY_LEFT => .go_west,
        curses.KEY_RIGHT => .go_east,
        curses.KEY_UP => .go_north,
        curses.KEY_DOWN => .go_south,
        '<' => .ascend,
        '>' => .descend,
        '?' => .help,
        'q' => .quit,
        's' => .search,
        ',' => .take_item,
        else => .wait,
    };
}

pub fn readKeypress(self: *Self) Keypress {
    _ = self;
    const ch = paranoia(curses.getch());
    return switch (ch) {
        curses.KEY_LEFT => .key_left,
        curses.KEY_RIGHT => .key_right,
        curses.KEY_UP => .key_up,
        curses.KEY_DOWN => .key_down,
        else => @enumFromInt(ch),
    };
}

pub fn refresh(self: *Self) void {
    _ = self;
    paranoiaVoid(curses.refresh()); // no error cases defined
}

pub fn renderChar(self: *Self, tile: DisplayTile) u8 {
    _ = self;
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

pub fn setChar(self: *Self, x: u16, y: u16, c: u8) void {
    // Client, etc., controls exact placement
    if (y < curses.getmaxy(self.win)) {
        paranoiaVoid(curses.mvaddch(y, x, c));
    }
    // else dump it
}

pub fn setText(self: *Self, x: u16, y: u16, s: []const u8) void {
    _ = self;

    if (s.len > 0) { // Interface apparently insists
        _ = paranoia(curses.mvaddnstr(y, x, s.ptr, @intCast(s.len)));
    }
}

//
// Unit Tests
//

// Avoid - this means dragging in ncurses to the test rig and cases where
// error generation botches the display

// EOF
