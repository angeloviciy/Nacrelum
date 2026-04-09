import Cocoa

let SCALE: CGFloat = 7

// ── Gold Cat Colors ──────────────────────────────────────────────
let bodyColor = NSColor(red: 0.91, green: 0.71, blue: 0.21, alpha: 1)      // Gold #E8B635
let shadowColor = NSColor(red: 0.77, green: 0.60, blue: 0.17, alpha: 1)    // Dark gold
let eyeColor = NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)          // White (visible on gold)
let noseColor = NSColor(red: 0.55, green: 0.35, blue: 0.20, alpha: 1)      // Brown-pink
let haloColor = NSColor(red: 1.0, green: 0.95, blue: 0.60, alpha: 0.85)    // Pale glowing gold
let earInnerColor = NSColor(red: 0.85, green: 0.55, blue: 0.40, alpha: 1)  // Pinkish inner ear

// ── Star Treat Colors ────────────────────────────────────────────
let starColors: [Int: NSColor] = [
    1: NSColor(red: 0.15, green: 0.12, blue: 0.05, alpha: 1),   // outline
    2: NSColor(red: 1.0, green: 0.95, blue: 0.60, alpha: 1),    // pale gold
    3: NSColor(red: 0.91, green: 0.71, blue: 0.21, alpha: 1),   // gold
    4: NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1),      // white center
]

// ── Star Treat Grid (11x11, 4-pointed star) ──────────────────────
let starGrid: [[Int]] = [
    [0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 1, 3, 1, 0, 0, 0, 0],
    [0, 0, 0, 0, 1, 3, 1, 0, 0, 0, 0],
    [0, 0, 0, 1, 2, 3, 2, 1, 0, 0, 0],
    [0, 1, 1, 2, 3, 4, 3, 2, 1, 1, 0],
    [1, 3, 3, 3, 4, 4, 4, 3, 3, 3, 1],
    [0, 1, 1, 2, 3, 4, 3, 2, 1, 1, 0],
    [0, 0, 0, 1, 2, 3, 2, 1, 0, 0, 0],
    [0, 0, 0, 0, 1, 3, 1, 0, 0, 0, 0],
    [0, 0, 0, 0, 1, 3, 1, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0],
]

let STAR_SCALE: CGFloat = 2
let STAR_PADDING: CGFloat = 5
let SHADOW_FLOOR_MARGIN: CGFloat = 48
let SHADOW_VIEW_HEIGHT: CGFloat = 6 * SCALE + SHADOW_FLOOR_MARGIN

// ── Cat Body Grid (10 wide x 7 tall, side-view facing right) ────
//   Right side = head/front, left side = body/back/tail
let bodyGrid: [[Int]] = [
    // Row 0 (top): ear tips
    [0, 0, 0, 0, 0, 1, 0, 1, 0, 0],
    // Row 1: ears + top of head
    [0, 0, 0, 0, 1, 1, 1, 1, 0, 0],
    // Row 2: head (widest — eyes drawn here)
    [0, 0, 0, 0, 1, 1, 1, 1, 1, 0],
    // Row 3: lower head / chin
    [0, 0, 0, 0, 1, 1, 1, 1, 0, 0],
    // Row 4: neck + upper body
    [0, 0, 1, 1, 1, 1, 1, 0, 0, 0],
    // Row 5: main body
    [0, 1, 1, 1, 1, 1, 0, 0, 0, 0],
    // Row 6 (bottom): rump
    [0, 0, 1, 1, 1, 0, 0, 0, 0, 0],
]

// ── Halo Grid (10 wide x 3 tall, centered over head) ────────────
let haloGrid: [[Int]] = [
    [0, 0, 0, 0, 1, 1, 1, 1, 0, 0],
    [0, 0, 0, 1, 0, 0, 0, 0, 1, 0],
    [0, 0, 0, 0, 1, 1, 1, 1, 0, 0],
]

// ── Leg Grids (10 wide x 3 tall, 4 legs) ────────────────────────
//   Back pair at cols 1,3 (under body), front pair at cols 6,8 (under head)
let pawsIdle: [[Int]] = [
    [0, 1, 0, 1, 0, 0, 1, 0, 1, 0],
    [0, 1, 0, 1, 0, 0, 1, 0, 1, 0],
    [0, 1, 0, 1, 0, 0, 1, 0, 1, 0],
]

let pawsWalk: [[Int]] = [
    [1, 0, 0, 1, 0, 0, 1, 0, 0, 1],
    [1, 0, 0, 1, 0, 0, 1, 0, 0, 1],
    [1, 0, 0, 1, 0, 0, 1, 0, 0, 1],
]

let pawsSquish: [[Int]] = [
    [1, 0, 0, 1, 0, 0, 1, 0, 0, 1],
    [1, 0, 0, 1, 0, 0, 1, 0, 0, 1],
    [1, 0, 0, 1, 0, 0, 1, 0, 0, 1],
]

let pawsRising: [[Int]] = [
    [0, 0, 1, 0, 0, 0, 0, 1, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
]

let pawsFalling: [[Int]] = [
    [0, 1, 0, 1, 0, 0, 1, 0, 1, 0],
    [0, 1, 0, 0, 0, 0, 0, 0, 1, 0],
    [0, 1, 0, 0, 0, 0, 0, 0, 1, 0],
]

let pawsLand: [[Int]] = [
    [1, 0, 0, 1, 0, 0, 1, 0, 0, 1],
    [1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    [1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
]

let pawsLandRecover: [[Int]] = [
    [1, 0, 0, 1, 0, 0, 1, 0, 0, 1],
    [1, 0, 0, 1, 0, 0, 1, 0, 0, 1],
    [0, 0, 0, 1, 0, 0, 1, 0, 0, 0],
]
