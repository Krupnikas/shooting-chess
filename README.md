# Shooting Chess

A chess variant that adds HP, healing, and shooting mechanics to create entirely new tactical possibilities.

## Game Rules

### Setup
- Standard 8x8 chess board
- Standard initial piece positions

### Base HP Values
Each piece has a base health point (HP) value set at the beginning of each turn:

| Piece  | Base HP |
|--------|---------|
| Pawn   | 1       |
| Knight | 3       |
| Bishop | 3       |
| Rook   | 4       |
| Queen  | 8       |
| King   | 8       |

### Turn Structure

Each turn consists of three phases:

1. **Reinforce Phase** - For each of your pieces, it "reinforces" all friendly pieces it can attack (according to standard chess movement rules) by +1 HP. HP can exceed the base value! For example, a pawn (base 1 HP) covered by 3 friendly pieces will have 4 HP after reinforcement. Visualized with a green ball animation.

2. **Shooting Phase** - For each of your pieces, it "shoots" all enemy pieces it can attack by -1 HP. Damage is visualized with a red ball animation. If a piece's HP reaches 0, it dies and is removed from the board.

3. **Move Phase** - Standard chess move (move, attack, or capture a piece using normal chess rules).

### Victory Condition
The game ends when a king's HP reaches 0 and it dies. There is no checkmate - the king must actually be killed through shooting damage.

### Key Strategic Differences from Standard Chess
- Pieces can be eliminated without being captured directly
- Positioning matters for both offense (shooting) and defense (healing)
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
