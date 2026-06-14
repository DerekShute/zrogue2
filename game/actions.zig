//!
//! Player action handler
//!

const std = @import("std");

const Action = @import("roguelib").Action;
const Entity = @import("roguelib").Entity;
const Map = @import("roguelib").Map;
const Player = @import("Player.zig");
const Pos = @import("roguelib").Pos;
const Region = @import("roguelib").Region;
const features = @import("features.zig");
const mapgen = @import("mapgen.zig");

//
// Types
//

// Function call prototype

const Handler = *const fn (self: *Player, action: *Action, map: *Map) Action.Result;

//
// Action service
//

pub fn doAction(entity: *Entity, map: *Map) !Action.Result {
    const player: *Player = @ptrCast(@alignCast(entity));

    var action = player.getAction() catch return error.Failed;
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

    const ret = actFn(player, &action, map);
    player.notifyDisplay(map);
    return ret;
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
    if (mapgen.getFloor(map, player.getPos()) == .stairs_up) {
        player.addMessage("You ascend closer to the exit..."); // TODO stupid
        return .ascend;
    }
    player.addMessage("I see no way up");
    return .continue_game;
}

fn doDescend(player: *Player, action: *Action, map: *Map) Action.Result {
    _ = action;
    if (mapgen.getFloor(map, player.getPos()) == .stairs_down) {
        player.addMessage("You go ever deeper into the dungeon...");
        return .descend;
    }

    player.addMessage("I see no way down");
    return .continue_game;
}

fn doMove(player: *Player, action: *Action, map: *Map) Action.Result {
    const new_pos = Pos.add(player.getPos(), action.getPos());

    if (!map.isPassable(new_pos)) {
        player.addMessage("Ouch!"); // FUTURE: 'bump' callback
        return .continue_game;
    }

    if (map.getEntity(new_pos) != null) {
        player.addMessage("Somebody is there!"); // FUTURE: bump or combat
        return .continue_game;
    }

    move(player, map, new_pos);

    return .continue_game;
}

fn doQuit(player: *Player, action: *Action, map: *Map) Action.Result {
    _ = player;
    _ = action;
    _ = map;
    // FUTURE: save, ask, etc.
    return .end_game;
}

fn doSearch(player: *Player, action: *Action, map: *Map) Action.Result {
    _ = action;

    var r = Region.configRadius(player.getPos(), 1);
    var i = r.iterator();
    var found: bool = false;
    while (i.next()) |pos| {
        found |= features.find(player, map, pos);
    }

    // FUTURE: when clients can handle multiple messages, embed in handler
    if (found) {
        player.addMessage("You find something!");
    } else {
        player.addMessage("You find nothing!");
    }

    return .continue_game;
}

fn doTake(player: *Player, action: *Action, map: *Map) Action.Result {
    if (mapgen.getItem(map, action.getPos()) == .gold) {
        player.addMessage("You pick up the gold!");
        player.incrementPurse();
        mapgen.addItem(map, action.getPos(), .unknown);
    } else {
        player.addMessage("Nothing here to take!");
    }

    return .continue_game;
}

//
// Utilities
//

// Move the entity to a new position in the map
//
// (Might be assuming adjacent to old)
//
pub fn move(player: *Player, map: *Map, new_pos: Pos) void {
    const old_pos = player.getPos();

    // FUTURE: feature trigger to leave position

    map.removeEntity(old_pos);
    player.setPos(new_pos);
    map.addEntity(player.getEntity(), new_pos);

    const new_floor = mapgen.getFloor(map, new_pos);
    const old_floor = mapgen.getFloor(map, old_pos);
    const new_lit = map.isLit(new_pos);
    const old_lit = map.isLit(old_pos);

    // This sort of how urogue manages it: room floor and corridors are
    // different tiles and movement between will light and extinguish the
    // room

    if ((old_floor == .door) and (new_floor == .floor)) {
        // Into the room properly
        player.setRegionVisible(.configRadius(old_pos, 1), false);
    } else if ((new_floor == .door) and (old_floor == .corridor)) {
        // Into threshold
        player.setRegionVisible(.configRadius(old_pos, 1), false);
        enterRoom(player, map);
    } else if ((new_floor == .corridor) and (old_floor == .door)) {
        // Leaving threshold and into dark corridor
        leaveRoom(player, map, old_pos);
    } else if (!new_lit and !old_lit) {
        // Moving around in a corridor or a dark room
        player.setRegionVisible(.configRadius(old_pos, 1), false);
    }
    player.setRegionVisible(.configRadius(new_pos, 1), true);

    features.enter(player, map, new_pos);
}

//
// Rooms
//

// Enter a room

pub fn enterRoom(player: *Player, map: *Map) void {
    if (map.isLit(player.getPos())) {
        // Entering a lit room : update what is now visible
        if (map.getRoomRegion(player.getPos())) |region| {
            player.setRegionVisible(region, true);
        }
    } else {
        // When being inserted onto a new level and initial room is dark...

        player.setRegionVisible(.configRadius(player.getPos(), 1), true);
    }

    // FUTURE: triggers for monsters, etc.
}

// Leave a room

pub fn leaveRoom(player: *Player, map: *Map, old_pos: Pos) void {
    if (map.isLit(old_pos)) {
        // Leaving a lit room : update what is now visible
        if (map.getRoomRegion(old_pos)) |region| {
            player.setRegionVisible(region, false);
        }
    }

    // FUTURE: triggers for monsters, etc.
}

// EOF
