# Shooting Chess - Implementation Plan

## Overview

Build a cross-platform Shooting Chess game using Godot 4.x with GDScript. The game features animated reinforce/shooting phases and standard chess move mechanics. Targets: Web, macOS, Windows, Linux, iOS, Android.

---

## Phase 1: Project Setup & Core Data Structures

### 1.1 Project Initialization
- Create new Godot 4.x project
- Set up project settings (window size, stretch mode for responsiveness)
- Configure export presets for target platforms
- Set up folder structure

### 1.2 Core Classes & Enums (GDScript)
```gdscript
# Enums
enum PieceType { PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING }
enum PieceColor { WHITE, BLACK }
enum GamePhase { REINFORCE, SHOOTING, MOVING, GAME_OVER }

# Piece class
class_name Piece
var type: PieceType
var color: PieceColor
var hp: int
var base_hp: int
var board_position: Vector2i

# GameState (managed by GameManager autoload)
var board: Array[Array]  # 8x8 grid of Piece or null
var current_player: PieceColor
var game_phase: GamePhase
var winner: PieceColor
```

### 1.3 Game Constants
```gdscript
const BASE_HP = {
    PieceType.PAWN: 1,
    PieceType.KNIGHT: 3,
    PieceType.BISHOP: 3,
    PieceType.ROOK: 4,
    PieceType.QUEEN: 8,
    PieceType.KING: 8
}
const BOARD_SIZE = 8
```

---

## Phase 2: Chess Logic Engine

### 2.1 Board Representation
- 2D array (8x8) storing Piece references or null
- Utility functions: `get_piece_at(pos)`, `set_piece_at(pos, piece)`, `remove_piece(pos)`
- Board initialization with standard chess setup

### 2.2 Movement Rules
- Implement `get_valid_moves(piece) -> Array[Vector2i]` for each piece type:
  - Pawn (forward, diagonal capture, initial two-square)
  - Knight (L-shaped, can jump)
  - Bishop (diagonals)
  - Rook (straight lines)
  - Queen (diagonal + straight)
  - King (one square any direction)
- Path blocking detection for sliding pieces (bishop, rook, queen)
- Board boundary validation

### 2.3 Attack Range Calculation
- `get_attack_targets(piece) -> Array[Vector2i]` - squares piece can attack
- `get_friendly_targets(piece) -> Array[Piece]` - for reinforcement
- `get_enemy_targets(piece) -> Array[Piece]` - for shooting

---

## Phase 3: Turn System & Game Phases

### 3.1 HP Management
- Reset all pieces to base HP at turn start
- Track current HP (can exceed base after reinforcement)
- Handle piece death: emit signal, queue_free(), update board array

### 3.2 Reinforce Phase Logic
- For each piece of current player:
  - Get all friendly pieces in attack range
  - Add +1 HP to each (stacks above base)
- Emit signals for animation system
- Example: Pawn (base 1) covered by 3 allies → 4 HP

### 3.3 Shooting Phase Logic
- For each piece of current player:
  - Get all enemy pieces in attack range
  - Subtract -1 HP from each
  - If HP <= 0: mark for death
- Process deaths after all shooting resolves
- Emit signals for animation

### 3.4 Move Phase Logic
- Wait for player to select piece
- Show valid moves (highlight squares)
- Validate and execute move
- Handle captures
- Switch player and start next turn

### 3.5 Win Condition
- After shooting phase, check if enemy king HP <= 0
- Emit game_over signal with winner

---

## Phase 4: Scenes & UI

### 4.1 Scene Structure
```
Main (Node2D)
├── Board (Node2D)
│   ├── Squares (TileMap or ColorRects)
│   └── Pieces (Node2D container)
├── UI (CanvasLayer)
│   ├── GameInfo (current player, phase)
│   ├── HPBars (or labels on pieces)
│   └── GameOverPanel
├── AnimationLayer (CanvasLayer)
│   └── Projectiles container
└── AudioPlayer
```

### 4.2 Board Scene
- 8x8 grid using TileMap or generated ColorRect squares
- Alternating colors (light/dark)
- Highlight layer for valid moves

### 4.3 Piece Scene
- Sprite2D with chess piece texture
- Label or ProgressBar for HP display
- Area2D for click detection
- Script handling selection and movement

### 4.4 UI Elements
- Current player indicator
- Current phase indicator
- New Game button
- Game Over overlay with winner

---

## Phase 5: Animations

### 5.1 Projectile System
- Projectile scene: Sprite2D + Tween or AnimationPlayer
- Green projectile for reinforce (+1 HP)
- Red projectile for shooting (-1 HP)
- Travel from source piece to target piece

### 5.2 Animation Flow
```gdscript
# Reinforce phase
for piece in player_pieces:
    for target in get_friendly_targets(piece):
        spawn_projectile(piece.position, target.position, "green")
        await projectile.finished
        target.hp += 1
        target.update_hp_display()

# Shooting phase (similar with red, damage)
```

### 5.3 Death Animation
- Fade out or particle effect when piece dies
- Remove from board after animation

### 5.4 Movement Animation
- Tween piece position from source to destination
- Optional: capture animation

---

## Phase 6: Polish & Platform Support

### 6.1 Game Features
- New game / restart button
- Move history (optional)
- Sound effects (optional)

### 6.2 Responsive Design
- Use Godot's stretch modes (canvas_items, expand)
- Touch input for mobile
- Mouse input for desktop/web

### 6.3 Export Configuration
- Web: HTML5 export template
- Desktop: macOS, Windows, Linux templates
- Mobile: iOS (requires Mac + Xcode), Android (requires Android SDK)

---

## Project Structure

```
shooting-chess/
├── project.godot
├── assets/
│   ├── pieces/           # Chess piece sprites (PNG/SVG)
│   ├── sounds/           # Sound effects (optional)
│   └── fonts/            # Custom fonts
├── scenes/
│   ├── main.tscn         # Main game scene
│   ├── board.tscn        # Chess board
│   ├── piece.tscn        # Individual piece
│   ├── projectile.tscn   # Reinforce/shoot projectile
│   └── ui/
│       ├── game_info.tscn
│       └── game_over.tscn
├── scripts/
│   ├── autoload/
│   │   └── game_manager.gd    # Global game state
│   ├── board.gd               # Board logic
│   ├── piece.gd               # Piece behavior
│   ├── move_rules.gd          # Chess movement rules
│   ├── projectile.gd          # Projectile animation
│   └── ui/
│       ├── game_info.gd
│       └── game_over.gd
└── export_presets.cfg
```

---

## Development Order

1. Create Godot project, set up window and stretch settings
2. Create board scene with 8x8 grid visuals
3. Create piece scene with placeholder sprites
4. Implement board initialization (standard chess setup)
5. Add piece selection (click detection)
6. Implement movement rules for each piece type
7. Add valid move highlighting and move execution
8. Implement HP system and display
9. Implement reinforce phase logic
10. Implement shooting phase logic
11. Add projectile animations (green/red balls)
12. Implement death handling and win condition
13. Add UI (player turn, phase, game over)
14. Add restart functionality
15. Test and polish
16. Configure export presets for all platforms
