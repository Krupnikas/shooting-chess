# Debug Session State - Shooting Chess Freeze Investigation

## Problem
Game freezes with spinning cursor (main thread blocked) at around 25-30 seconds of gameplay.

## What We Tested

### Confirmed NOT the cause:
- Tweens (disabled - still froze)
- Console logging/print() (disabled - still froze)
- File logging (disabled - still froze)
- Time label update every frame (reduced to every 30 frames - still froze)
- Projectiles alone (disabled - still froze at ~47s)
- board._process() state machine (disabled - still froze)

### Confirmed Working:
- Minimal "Hello World" + timer scene runs 2+ minutes without freeze
- Godot engine itself is fine

## Current Code State

### Feature Flags in board.gd:
```gdscript
const ENABLE_PROJECTILES = false  # Currently disabled
const ENABLE_HIGHLIGHTS = true
const ENABLE_TWEENS = true
const ENABLE_HEARTBEAT_LOG = false
const ENABLE_TRACE_LOG = false
```

### Changes Made:
1. Removed REINFORCE phase - now only MOVING -> SHOOTING
2. Simplified projectile system - white pieces shoot white balls, black shoot black
3. Same color hit = heal, different color = damage
4. Added autotest that avoids capturing kings
5. Reduced time label updates to every 30 frames

### Files Modified:
- scripts/board.gd - state machine, feature flags
- scripts/projectile.gd - color-based logic
- scripts/autoload/game_manager.gd - removed REINFORCE phase
- scripts/autoload/auto_test.gd - auto-play for testing
- scripts/ui/game_info.gd - reduced timer updates
- scripts/piece.gd - tweens (currently enabled)
- project.godot - changed main scene to minimal_test.tscn

### Current project.godot main scene:
```
run/main_scene="res://scenes/minimal_test.tscn"
```
Change back to `res://scenes/main.tscn` for normal game.

### Autoloads currently disabled:
```
#GameManager="*res://scripts/autoload/game_manager.gd"
#AutoTest="*res://scripts/autoload/auto_test.gd"
```

## Next Steps to Debug

1. Re-enable the game scene (change main_scene back to main.tscn)
2. Re-enable autoloads
3. Keep projectiles disabled (ENABLE_PROJECTILES = false)
4. Test if it still freezes
5. If yes - the freeze is in the basic chess/piece/highlight logic
6. If no - the freeze is in the projectile system

## Hypothesis
The freeze seems to accumulate over time and is related to the amount of work/allocations done. More features = faster freeze (25s), fewer features = slower freeze (47s+).

Possible causes:
- Memory leak/accumulation
- Godot GC behavior
- Signal connection accumulation
- Node tree operations

## To Restore Full Game:
1. Edit project.godot:
   - Change main_scene to "res://scenes/main.tscn"
   - Uncomment autoloads
2. In board.gd, set ENABLE_PROJECTILES = true
3. Test incrementally, enabling features one by one
