## Layout

A work in progress.  There is:

* roguelib : generic map-and-mechanics
* mapgen : map generation services.  This may get broken apart so that the game
  controls mapgen
* game : the game that would be implemented, that wields the mapgen and
  roguelib
* doc : you are here
* linux-cli : what it says on the tin: Linux single-user ncurses-based game
* testing : high level testing that is a game equivalent

## Modules

### game

The game, in whatever form it currently exists

### mapgen

Anything related to map generation: room placement, corridors, items, and
initial player placement.

Admittedly some of this should be pushed at the game level.

#### test_level

A fixed generator that includes no random element.  This is used to guarantee
that certain things exist, and is the basis for the step-by-step testing rig.

#### rogue_level

A map generated per the original Rogue sources or near enough.

### roguelib

The most generally-useful things I can think of.  Positions, maps of tiles,
Entities, and so forth.  These are the substrate.

### linux-cli

This is the Linux CLI single-user game, using ncurses.

#### ncurses

This implements the traditional 'rogue' experience.  You get an 80x24 display
with message line at the top and stats at the bottom.

Keypresses convert to Actions driving the game engine, and those Actions drive
display updates back to the Provider.

I look forward to figuring out how to process complex events, such as asking
what inventory item to consume or what location to target for a fireball.

## Test scaffolding

Zig is amazing in this regard and I'm trying to work a top-level testing
directory that approaches it holistically, with all knowledge of all modules.
That way the unit tests in each subdir can be specific.

The goal is that each subsection, each element can be unit tested for
correctness.  Bugfixes should be boiled down to unit test validation.

## Code Coverage

I'll need to revisit this when kcov works with 26.04 or reliably in the GitHub
workflow.

I personally consider code coverage to be a pillar of testing strategy and
have used it elsewhere to really crush out bugs.

## Doc generation

Clearly a work in progress for Zig 0.14.  I will try for due diligence.

## Visualization

Worked in the previous repository but not here.