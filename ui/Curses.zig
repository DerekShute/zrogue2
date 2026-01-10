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
// Members
//

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

// We really don't expect this to fail.
fn paranoia(res: c_int) c_int {
    if (res == curses.ERR) {
        unreachable;
    }
    return res;
}

//
// Convert map location to what it is displayed as
//
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

fn renderChar(tile: Provider.DisplayMapTile) u8 {
    if (tile.visible) {
        if (tile.entity != .unknown) {
            return mapToChar(tile.entity);
        }
        if (tile.item != .unknown) {
            return mapToChar(tile.item);
        }
        // Else floor
    } else { // Not visible
        // Provider option: can use dimmed version of last known, etc
        if (!tile.floor.isFeature()) {
            return mapToChar(.unknown);
        }
    }

    return mapToChar(tile.floor);
}

fn renderMap(p: *Provider) void {
    // Row 0 is message line, last row (23) is stats, so map 0,0 is at
    // position 0,1

    if (p.displayChange()) |dc| { // if there's a change
        var _dc = dc;
        while (_dc.next()) |r| {
            if (r.y < p.y - 2) { // Reserve bottom display line
                _ = paranoia(curses.mvaddch(
                    r.y + 1, // Shift one to reserve top line
                    r.x,
                    renderChar(p.getTile(r.x, r.y)),
                ));
            }
        }
    }
}

//
// Global state
//

var global_win: ?*curses.WINDOW = null;

//
// Members
//

p: Provider = undefined,
// Stats
purse: i32 = 0,
depth: i32 = 0,

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
    _ = paranoia(curses.raw());
    _ = paranoia(curses.keypad(global_win, true));
    _ = paranoia(curses.noecho());
    // curs_set: ERR only if argument value is unsupported
    _ = paranoia(curses.curs_set(0));

    // getmaxx/getmaxy ERR iff null window parameter
    const display_maxx = paranoia(curses.getmaxx(global_win));
    const display_maxy = paranoia(curses.getmaxy(global_win));

    if ((display_maxx < config.maxx) or (display_maxy < config.maxy)) {
        return Provider.Error.DisplayTooSmall;
    }

    const pc: Provider.Config = .{
        .allocator = config.allocator,
        .maxx = config.maxx,
        .maxy = config.maxy,
        .vtable = &.{
            .getCommand = cursesGetCommand,
            .notifyDisplay = cursesNotifyDisplay,
            .setStatInt = cursesSetStatInt,
        },
    };

    return .{
        .p = try Provider.init(pc),
    };
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.p.deinit(allocator);
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
        _ = paranoia(curses.mvaddnstr(y, x, s.ptr, @intCast(s.len)));
    }
}

fn refresh() void {
    // refresh: no error cases defined
    _ = paranoia(curses.refresh());
}

//
// Input Utility
//

fn readCommand() Provider.Command {
    // TODO Future: resize 'key'

    const ch = paranoia(curses.getch());
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
    //         Create a map of command <-> keypress for display here?
    mvaddstr(0, 0, "*                                                                              *");
    mvaddstr(0, 1, "         Welcome to the Dungeon of Doom          ");
    mvaddstr(0, 2, "                                                 ");
    mvaddstr(0, 3, " Use the arrow keys to move through the dungeon  ");
    mvaddstr(0, 4, " and collect gold.  You can only return to the   ");
    mvaddstr(0, 5, " surface after you have descended to the bottom. ");
    mvaddstr(0, 6, "                                                 ");
    mvaddstr(0, 7, " Commands include:                               ");
    mvaddstr(0, 8, "    ? - help (this)                              ");
    mvaddstr(0, 9, "    > - descend stairs (\">\")                     ");
    mvaddstr(0, 10, "    < - ascend stairs (\"<\")                      ");
    mvaddstr(0, 11, "    , - pick up gold  (\"$\")                      ");
    mvaddstr(0, 12, "    s - search for hidden doors                  ");
    mvaddstr(0, 13, "    q - chicken out and quit                     ");
    mvaddstr(0, 14, "                                                 ");
    mvaddstr(0, 15, " [type a command or any other key to continue]   ");
    mvaddstr(0, 16, "                                                 ");
    mvaddstr(0, 23, "*                                                                              *");
    refresh();
}

fn displayStatLine(self: *Self) void {
    // msg("Level: %d  Gold: %-5d  Hp: %*d(%*d)  Str: %2d(%d)  Arm: %-2d  Exp: %d/%ld  %s", ...)
    var buf: [80]u8 = undefined; // does this need to be allocated?  size?

    const fmt = "Level: {}  Gold: {:<5}  Hp: some";
    const u_purse: u32 = @intCast(self.purse);
    const output = .{ self.depth, u_purse };

    // We know that error.NoSpaceLeft can't happen here
    const line = std.fmt.bufPrint(&buf, fmt, output) catch unreachable;
    mvaddstr(0, @intCast(self.p.y - 1), line);
}

fn displayScreen(self: *Self) !void {
    //
    // Top line: messages
    //
    mvaddstr(0, 0, "                                                  ");
    mvaddstr(0, 0, self.p.getMessage());

    //
    // Bottom line: stat block
    //

    self.displayStatLine();

    //
    // Middle: the map
    //
    renderMap(&self.p);

    // Regenerate display

    refresh();
}

//
// VTable Methods
//
// NotInitialized in here could be a panic instead of error return but
// the mock display also uses it to test for API correctness.

fn cursesGetCommand(ptr: *anyopaque) Provider.Command {
    const self: *Self = @ptrCast(@alignCast(ptr));

    if (global_win == null) {
        // Punish programmatic errors
        @panic("getCommand but not initialized");
    }

    var cmd = readCommand();
    while (cmd == .help) {
        displayHelp();
        cmd = readCommand();
        // TODO: hit help a second time to rid menu
    }

    self.p.clearMessage();

    return cmd;
}

fn cursesNotifyDisplay(ptr: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ptr));

    if (global_win == null) {
        // Punish programmatic errors
        @panic("cursesNotifyDisplay but not initialized");
    }

    self.displayScreen() catch unreachable;
}

fn cursesSetStatInt(ptr: *anyopaque, name: []const u8, value: i32) void {
    const self: *Self = @ptrCast(@alignCast(ptr));

    if (std.mem.eql(u8, "purse", name)) {
        self.purse = value;
    } else if (std.mem.eql(u8, "depth", name)) {
        self.depth = value;
    }

    if (global_win != null) {
        self.displayStatLine();
        refresh();
    }
}

//
// Unit Tests
//

// Avoid - this means dragging in ncurses to the test rig and cases where
// error generation botches the display

// EOF
