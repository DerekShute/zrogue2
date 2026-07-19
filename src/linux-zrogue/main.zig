//!
//! zrogue as CLI application
//!

const std = @import("std");
const Game = @import("game");
const Curses = @import("Curses.zig");
const options = @import("build");

//
// Constants
//

const MAX_DEPTH = 3;

//
// Command arguments
//

fn arg_in_list(programarg: []const u8, l: []const []const u8) bool {
    for (l) |a| {
        if (std.mem.eql(u8, programarg, a)) {
            return true;
        }
    }
    return false;
}

// Help display

const help_arg_flags = [_][]const u8{ "-h", "-help", "--help" };

fn print_help(init: std.process.Init) !void {
    var stdout_writer = std.Io.File.stdout().writer(init.io, &.{});
    const stdout = &stdout_writer.interface;

    const help =
        \\
        \\ This program requires a 80x24 text display.
        \\
        \\ options:
        \\   --help, -h : help
        \\   --version, -v : version
        \\
        \\ Press '?' for in-game help
        \\
    ;
    try stdout.print("Zrogue : Adventuring in the Dungeons of Doom\n", .{});
    try stdout.print(" version {s}\n", .{options.version});
    try stdout.print("{s}\n", .{help});
    try stdout.flush();
}

// Version display

const version_arg_flags = [_][]const u8{ "-v", "-version", "--version" };

fn print_version(init: std.process.Init) !void {
    var stdout_writer = std.Io.File.stdout().writer(init.io, &.{});
    const stdout = &stdout_writer.interface; // Writer

    try stdout.print("Zrogue version {s}\n", .{options.version});
    try stdout.flush();
}

//
// Main entrypoint of Linux single-player CLI using Curses
//

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    //
    // Arguments
    //
    // Note that this does not work from 'build run'
    //

    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len > 1) { // program name is args[0]
        for (args) |arg| {
            if (arg_in_list(arg[0..], &help_arg_flags)) {
                try print_help(init);
                std.process.exit(0);
            }
            if (arg_in_list(arg[0..], &version_arg_flags)) {
                try print_version(init);
                std.process.exit(0);
            }
        }
        try print_help(init);
        std.process.exit(1);
    }

    //
    // Initialize display and start program
    //

    // REFACTOR: this isn't great.  The game-ui should dictate constraints and
    // should probably give the opportunity to resize the display

    var curses = Curses.init() catch |err| switch (err) {
        error.DisplayTooSmall => {
            std.debug.print(
                "Zrogue requires an {}x{} display\n",
                .{ Game.XSIZE, Game.YSIZE },
            );
            std.process.exit(1);
        },
    };
    defer curses.deinit();

    const seed = std.Io.Timestamp.now(init.io, .real).toMicroseconds();
    var prng: std.Random.DefaultPrng = .init(@intCast(seed));

    var g = Game.init();
    g.configAllocator(allocator);
    g.configIo(init.io);
    g.configRandom(prng.random());
    defer g.deinit();

    const id = try g.initPlayer(.{ .client = curses.client() });
    defer g.deinitPlayer(id);

    var player = g.getPlayer(id); // TODO: ugh

    player.addMessage("Welcome to the Dungeon of Doom!");

    g.setGoingDown();

    var level: u16 = 1;
    var state: Game.State = .run;
    while (state != .end) {
        g.setLevel(level);
        player.resetFOV();
        try g.initLevel();
        defer g.deinitLevel();

        g.addPlayer(player, 0);

        state = g.run();

        // Simple map management: only one, and we replace it at change
        if (state == .descend) {
            level += 1;
            if (level >= MAX_DEPTH) {
                g.setGoingUp();
            }
        } else if (state == .ascend) {
            level -= 1;
            if (level < 1) {
                break;
            }
        }
    } // Game run loop

    // FUTURE: game endings go here
}

//
// Unit Tests
//

// Handled as part of the testing subdir rig

// EOF
