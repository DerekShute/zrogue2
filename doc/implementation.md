## Layout

A work in progress.  There is:

* roguelib : generic map-and-mechanics
  * vis_main.zig : the thing that builds the visualization graph
  * testing : apparatus
* common : a bunch of stuff put here for dependency resolution
  * Probably belongs in game/
* connector : the network (Reader/Writer) protocol
* doc : you are here
* game : the game that would be implemented, that wields the mapgen and roguelib
  * ui.zig : the Rogue presentation / personality, used by the client and the standalone
    * keypress interpretation / element positioning and reporting
    * Technically a separate module, which may be a lousy idea
  * testing : apparatus
* src : source directory of various programs
  * cli-client : raw command-line network client for debugging and analysis
  * fuzz : fuzz/error testing for server
  * linux-client : client side of server.
  * linux-server : server side
  * linux-zrogue : single-player (standalone) game version
* ui : chum bucket for user interface
  * NCurses : low-level ncurses utilities (a separate module)

## Modules

### game

The game, in whatever form it currently exists

### roguelib

The most generally-useful things I can think of.  Positions, maps of tiles,
Entities, and so forth.  These are the substrate.

### ui (rogueui, for lack of better)

Chum bucket of ui elements, from the ncurses low-level utilities to the presentation layer for rogue that
sits on that (and is used by both the standalone and the network client)

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

### Call Graph visualization

The goal is to create a visualization that shows function call relationships
between components.  Zig and LLVM do support this.

The hooks provided by Internet Lookup appear to generate the expected LLVM
IR files:

```diff
+    const rogue_ir_file = rogue_exe.getEmittedLlvmIr();
+    const rogue_ir = b.addInstallFile(rogue_ir_file, "zrogue.ll");
+    b.getInstallStep().dependOn(&rogue_ir.step);
```

But there's an external tool problem that halts progress:

```
opt -passes=dot-callgraph zrogue.ll -disable-output
opt: zrogue.ll:802:74: error: expected ')' at end of argument list
define internal fastcc i16 @main.print_help(ptr nonnull readonly align 8 captures(none) %0) unnamed_addr #0 align 1 !dbg !5897 {
```

This might be a tool version problem between what Ubuntu is providing my system and what Zig uses internally.

## Network Protocol

Sits on top of Messagepack, because that seemed like a good idea at the time.
Message receipt is always done into a very limited allocator to prevent
malfeasance through some data bomb.  If it doesn't fit into 300 bytes then we
don't want it or whoever sent it.
