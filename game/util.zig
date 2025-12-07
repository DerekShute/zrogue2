//!
//! Player action handler, here at least for now
//!

const std = @import("std");

const Action = @import("roguelib").Action;
const Map = @import("roguelib").Map;
const Player = @import("Player.zig");

//
// Types
//

// Function call prototype

const Handler = *const fn (self: *Player, action: *Action, map: *Map) Action.Result;

//
// Action service
//

pub fn doPlayerAction(player: *Player, action: *Action, map: *Map) Action.Result {
    const actFn: Handler = switch (action.getType()) {
        .ascend => doAscend,
        .descend => doDescend,
        .move => doMove,
        .take => doTake,
        .quit => doQuit,
        .search => doSearch,
        .none => doNothing,
        .wait => doNothing, // TODO untrue
    };

    return actFn(player, action, map);
}

//
// Handlers
//

fn doNothing(player: *Player, action: *Action, map: *Map) Action.Result {
    _ = player;
    _ = action;
    _ = map;

    return .continue_game;
}

fn doAscend(player: *Player, action: *Action, map: *Map) Action.Result {
    _ = action;
    _ = map;
    player.addMessage("I see no way up");
    return .continue_game;
}

fn doDescend(player: *Player, action: *Action, map: *Map) Action.Result {
    _ = action;
    _ = map;
    player.addMessage("I see no way down");
    return .continue_game;
}

fn doMove(player: *Player, action: *Action, map: *Map) Action.Result {
    _ = action;
    _ = map;
    player.addMessage("Ouch!");
    return .continue_game;
}

fn doQuit(player: *Player, action: *Action, map: *Map) Action.Result {
    _ = player;
    _ = action;
    _ = map;
    // TODO: save, ask, etc.
    return .end_game;
}

fn doSearch(player: *Player, action: *Action, map: *Map) Action.Result {
    _ = action;
    _ = map;
    player.addMessage("You find nothing!");
    return .continue_game;
}

fn doTake(player: *Player, action: *Action, map: *Map) Action.Result {
    _ = action;
    _ = map;
    player.addMessage("Nothing here to take!");
    return .continue_game;
}

// EOF
