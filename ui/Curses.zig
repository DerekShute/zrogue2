//!
//! ncurses frontend, creating a Provider from it
//!
//!
//! * (0,0) is top left corner,
//! * Y incrementing down the display,
//! * X incrementing right
//!

const std = @import("std");
const curses = @cImport(@cInclude("curses.h"));

const Provider = @import("Provider.zig");
const Command = @import("roguelib").Command;
const MapTile = @import("roguelib").MapTile;

const Self = @This();

//
// Types
//

pub const Config = struct {
    maxx: u8,
    maxy: u8,
};

//
// Lifted from https://github.com/Akuli/curses-minesweeper
//
// Causes:
//
//   * Move cursor to x,y not supported by window size
//
fn checkError(res: c_int) Provider.Error!c_int {
    if (res == curses.ERR) {
        return Provider.Error.ProviderError; // Cop-out
    }
    return res;
}

//
// Convert map location to what it is displayed as
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
// Global state
//

var global_win: ?*curses.WINDOW = null;

//
// Members
//

p: Provider = undefined,

// TODO: cursor management

//
// Constructor / Destructor
//

pub fn init(config: Config) Provider.Error!Self {
    if (global_win != null) {
        return Provider.Error.AlreadyInitialized;
    }

    // Note technically can fail
    const res = curses.initscr();
    errdefer {
        _ = curses.endwin(); // error only if window uninitialized.
    }
    if (res) |res_val| {
        global_win = res_val;
    }

    // Instantly process events, and activate arrow keys
    // TODO Future: mouse events

    // raw/keypad/noecho: no defined error cases
    _ = checkError(curses.raw()) catch unreachable;
    _ = checkError(curses.keypad(global_win, true)) catch unreachable;
    _ = checkError(curses.noecho()) catch unreachable;
    // curs_set: ERR only if argument value is unsupported
    _ = checkError(curses.curs_set(0)) catch unreachable;

    // getmaxx/getmaxy ERR iff null window parameter
    const display_maxx = checkError(curses.getmaxx(global_win)) catch unreachable;
    const display_maxy = checkError(curses.getmaxy(global_win)) catch unreachable;

    if ((display_maxx < config.maxx) or (display_maxy < config.maxy)) {
        return Provider.Error.DisplayTooSmall;
    }

    return .{
        .p = .{
            .ptr = undefined,
            .x = config.maxx,
            .y = config.maxy,
            .vtable = &.{
                .getCommand = getCommand,
            },
        },
    };
}

pub fn deinit(self: *Self) void {
    _ = self;
    global_win = null;
    _ = curses.endwin(); // Liberal shut-up-and-do-it
}

//
// Lifecycle
//

pub fn provider(self: *Self) *Provider {
    self.p.ptr = self;
    return &self.p;
}

//
// Gross Utility Wrappers
//

fn mvaddstr(x: u16, y: u16, s: []const u8) void {
    // TODO errors here probably only because of display sizing

    if (s.len > 0) { // Interface apparently insists
        _ = checkError(curses.mvaddnstr(y, x, s.ptr, @intCast(s.len))) catch unreachable;
    }
}

fn refresh() void {
    // refresh: no error cases defined
    _ = checkError(curses.refresh()) catch unreachable;
}

//
// Input Utility
//

fn readCommand() Command {
    // TODO Future: resize 'key'

    const ch = checkError(curses.getch()) catch unreachable;
    return switch (ch) {
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

//
// Display Utility
//

fn displayHelp() void {
    // FIXME : This is horrible and adding to it is painful
    mvaddstr(0, 0, "*                                                                              *");
    mvaddstr(0, 1, "         Welcome to the Dungeon of Doom          ");
    mvaddstr(0, 2, "                                                 ");
    mvaddstr(0, 3, " Use the arrow keys to move through the dungeon  ");
    mvaddstr(0, 4, " and collect gold.  You can only return to the   ");
    mvaddstr(0, 5, " surface after you have descended to the bottom. ");
    mvaddstr(0, 6, "                                                 ");
    mvaddstr(0, 7, " Commands include:                               ");
    mvaddstr(0, 8, "    ? - help (this)                              ");
    mvaddstr(0, 9, "    > - descend stairs (\">\")                   ");
    mvaddstr(0, 10, "    < - ascend stairs (\"<\")                   ");
    mvaddstr(0, 11, "    , - pick up gold  (\"$\")                   ");
    mvaddstr(0, 12, "    s - search for hidden doors                 ");
    mvaddstr(0, 13, "    q - chicken out and quit                    ");
    mvaddstr(0, 14, "                                                ");
    mvaddstr(0, 15, " [type a command or any other key to continue]  ");
    mvaddstr(0, 16, "                                                ");
    mvaddstr(0, 23, "*                                                                              *");
    refresh();
}

fn displayScreen(self: *Self) !void {
    // TODO: only updates

    //
    // Top line: messages
    //
    // TODO: too narrow
    //
    mvaddstr(0, 0, "                                                  ");
    mvaddstr(0, 0, self.p.getMessage());
    self.p.clearMessage();

    //
    // Bottom line: stat block
    //
    // msg("Level: %d  Gold: %-5d  Hp: %*d(%*d)  Str: %2d(%d)  Arm: %-2d  Exp: %d/%ld  %s", ...)
    //
    // TODO: defined length, here
    var buf: [80]u8 = undefined; // does this need to be allocated?  size?

    const fmt = "Level: {}  Gold: {:<5}  Hp: some";
    const output = .{
        self.p.stats.depth,
        self.p.stats.purse,
    };

    // We know that error.NoSpaceLeft can't happen here
    const line = std.fmt.bufPrint(&buf, fmt, output) catch unreachable;
    // TODO if too narrow
    // TODO explicitly the bottom row, whatever the current screen height
    mvaddstr(0, @intCast(self.p.y), line);

    //
    // Output map display
    //
    // TODO off by one
    // TODO iterator
    //
    const map = self.p.display_map;
    for (0..@intCast(self.p.y - 1)) |y| {
        for (0..@intCast(self.p.x)) |x| {
            const t = map.find(@intCast(x), @intCast(y)) catch unreachable; // TODO
            _ = checkError(curses.mvaddch(@intCast(y + 1), @intCast(x), mapToChar(t.tile))) catch unreachable;
        }
    }

    refresh();
}

//
// VTable Methods
//
// NotInitialized in here could be a panic instead of error return but
// the mock display also uses it to test for API correctness.

fn getCommand(ptr: *anyopaque) Command {
    _ = ptr;
    //    const self: *Self = @ptrCast(@alignCast(ptr));

    if (global_win == null) {
        // Punish programmatic errors
        @panic("getCommand but not initialized");
    }

    // TODO need to build this out
    //    self.displayScreen() catch unreachable;
    displayHelp();

    var cmd = readCommand();
    while (cmd == .help) {
        displayHelp();
        cmd = readCommand();
    }
    return cmd;
}

//
// Unit Tests
//
const expectError = std.testing.expectError;

// TODO alloc fail test

// EOF
