# Shooting Chess

A chess variant that adds HP and shooting mechanics to create entirely new tactical possibilities.

## Game Rules

### Setup
- Standard 8x8 chess board
- Standard initial piece positions

### Base HP Values
Each piece has a base health point (HP) value:

| Piece  | Base HP |
|--------|---------|
| Pawn   | 1       |
| Knight | 3       |
| Bishop | 3       |
| Rook   | 4       |
| Queen  | 8       |
| King   | 8       |

### Turn Structure

Each turn consists of two phases:

1. **Move Phase** - At the start of your turn, your pieces' HP is reset to their base values. Then you make a standard chess move (move, attack, or capture using normal chess rules).

2. **Shooting Phase** - After you move, all your pieces shoot projectiles in their attack directions:
   - **Sliding pieces** (Bishop, Rook, Queen): Shoot projectiles in their movement directions that travel until hitting a piece or the board edge
   - **Targeted pieces** (Pawn, Knight, King): Shoot projectiles to specific cells they can attack

   Projectile color matches the piece that fired it (white pieces shoot white balls, black pieces shoot black balls).

   **Damage/Healing Rules:**
   - Same color hit = **+1 HP** (healing) - e.g., white ball hits white piece
   - Different color hit = **-1 HP** (damage) - e.g., white ball hits black piece

   If a piece's HP reaches 0, it dies and is removed from the board.

### Victory Condition
The game ends when a king's HP reaches 0 and it dies. There is no checkmate - the king must actually be killed through shooting damage.

### Key Strategic Differences from Standard Chess
- Pieces can be eliminated without being captured directly
- Your pieces heal each other when they can attack friendly pieces
- Enemy pieces damage each other when they can attack enemy pieces in your attack lines
- High-mobility pieces (Queen, Rooks, Bishops) become more valuable for area control
- Pawns are fragile (1 HP) and can be easily eliminated by concentrated fire
- The King needs protection not just from checkmate but from sustained damage

## Tech Stack

- **Engine**: Godot 4.x
- **Language**: GDScript
- **Platforms**: Web (HTML5), macOS, Windows, Linux, iOS, Android

## Development

### Prerequisites
- [Godot Engine 4.x](https://godotengine.org/download) (standard version, not .NET)

### Running the Game
1. Open Godot Engine
2. Click "Import" and select the `project.godot` file
3. Press F5 or click the Play button

### Exporting
Use Godot's export templates to build for each platform:
- **Web**: HTML5 export (runs in browser via WebAssembly)
- **Desktop**: macOS, Windows, Linux native builds
- **Mobile**: iOS and Android exports (requires additional setup for signing)
