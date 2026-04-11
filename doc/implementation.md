## Layout

A work in progress.  There is:

* roguelib : generic map-and-mechanics
  * protocol : the messaging protocol messages and test apparatus
* doc : you are here
* game : the game that would be implemented, that wields the mapgen and
  roguelib
* src : source directory of various programs
  * fuzz : fuzz/error testing for server
  * linux-client : client side of server
  * linux-server : server side
  * linux-zrogue : single-player game version
  * testing : apparatus
* ui : chum bucket for user interface

## Modules

### game

The game, in whatever form it currently exists

### roguelib

The most generally-useful things I can think of.  Positions, maps of tiles,
Entities, and so forth.  These are the substrate.

Also the messaging protocol minus the networking

#### ui/ncurses

This implements the traditional 'rogue' experience.  You get an 80x24 display
with message line at the top and stats at the bottom.

Keypresses convert to Actions driving the game engine, and those Actions drive
display updates back to the Provider.

I look forward to figuring out how to process complex events, such as asking
what inventory item to consume or what location to target for a fireball.

Looking forward I can see the 'game' aspects of UI being subsumed into some
kind of Personality module, so the linux-cli and the client sit on top of
similar logic controlling display of stats and message bar location and so
forth.

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

Clearly a work in progress for Zig 0.15.  I will try for due diligence.

## Visualization

Generates zig-out/visual.svg, which is a directed graph showing relationships
between structures in the roguelib subdir.  This is done by amazing comptime
magic threaded through some gross Python logic to hammer it into something
vaguely YAML-shaped.

Invoked by the Makefile, the visual target.

When I feel inspired, I'll do something to hook it into the documentation.

## Network Protocol

Sits on top of Messagepack, because that seemed like a good idea at the time.
Message receipt is always done into a very limited allocator to prevent
malfeasance through some data bomb.  If it doesn't fit into 300 bytes then we
don't want it or whoever sent it.
