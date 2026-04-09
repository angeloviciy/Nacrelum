import Cocoa

let SCALE: CGFloat = 7

// ── Gold Cat Colors (mapped from WhiteCat reference) ─────────────
// Original: 1=black outline, 2=pink ear, 3=white body, 4=grey shadow, 5=dark eyes
// Gold version:
let outlineColor = NSColor(red: 0.30, green: 0.22, blue: 0.05, alpha: 1)   // Dark brown outline
let earInnerColor = NSColor(red: 0.95, green: 0.50, blue: 0.50, alpha: 1)  // Pink inner ear
let bodyColor = NSColor(red: 0.91, green: 0.71, blue: 0.21, alpha: 1)      // Gold body
let shadowColor = NSColor(red: 0.77, green: 0.60, blue: 0.17, alpha: 1)    // Dark gold shadow
let eyeColor = NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)          // White eyes
let haloColor = NSColor(red: 1.0, green: 0.95, blue: 0.60, alpha: 0.85)    // Pale glowing gold
let bellyColor = NSColor(red: 0.96, green: 0.82, blue: 0.47, alpha: 1)     // Light gold (unused)
let chestColor = NSColor(red: 0.96, green: 0.82, blue: 0.47, alpha: 1)     // Light gold (unused)

// Grid color map: 0=empty, 1=outline, 2=earInner, 3=body, 4=shadow, 5=eye(animated)

// ── Star Treat Colors ────────────────────────────────────────────
let starColors: [Int: NSColor] = [
    1: NSColor(red: 0.15, green: 0.12, blue: 0.05, alpha: 1),
    2: NSColor(red: 1.0, green: 0.95, blue: 0.60, alpha: 1),
    3: NSColor(red: 0.91, green: 0.71, blue: 0.21, alpha: 1),
    4: NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1),
]

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

// ── Cat Body Grid (16 wide x 10 tall) ───────────────────────────
//   Extracted from WhiteCatIdle.png frame 0 (rows 0-9, head on right)
//   0=empty, 1=outline, 2=earInner, 3=body, 4=shadow, 5=eye(animated)
let bodyGrid: [[Int]] = [
    [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0],
    [0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 1, 0, 0, 1, 4, 1],
    [0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 3, 1, 1, 4, 4, 1],
    [0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 3, 3, 3, 3, 4, 1],
    [0, 0, 1, 0, 0, 0, 0, 1, 3, 3, 3, 3, 3, 3, 3, 1],
    [0, 1, 4, 1, 0, 0, 0, 1, 3, 3, 5, 3, 3, 5, 3, 1],
    [0, 0, 1, 4, 1, 0, 1, 1, 3, 3, 3, 3, 2, 3, 3, 1],
    [0, 0, 1, 4, 1, 1, 3, 3, 4, 3, 3, 3, 3, 3, 1, 0],
    [0, 0, 0, 1, 3, 3, 3, 3, 3, 4, 3, 3, 3, 1, 0, 0],
    [0, 0, 0, 0, 1, 3, 3, 3, 3, 3, 3, 3, 3, 1, 0, 0],
]

// ── Halo Grid (16 wide x 3 tall, centered over head) ────────────
let haloGrid: [[Int]] = [
    [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0],
]

// ── Leg Grids (16 wide x 2 tall) ────────────────────────────────
//   Extracted from WhiteCatIdle frame 0 bottom rows
let pawsIdle: [[Int]] = [
    [0, 0, 0, 0, 1, 3, 3, 1, 3, 3, 3, 1, 3, 1, 0, 0],
    [0, 0, 0, 0, 0, 1, 3, 1, 1, 3, 3, 1, 3, 1, 0, 0],
]

// Walk frame: derived from WhiteCatRun frame 1 bottom rows
let pawsWalk: [[Int]] = [
    [0, 0, 0, 0, 1, 4, 3, 4, 3, 1, 1, 1, 1, 0, 0, 0],
    [0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0],
]

let pawsSquish: [[Int]] = [
    [0, 0, 0, 0, 1, 3, 3, 1, 3, 3, 3, 1, 3, 1, 0, 0],
    [0, 0, 0, 0, 0, 1, 3, 1, 1, 3, 3, 1, 3, 1, 0, 0],
]

let pawsRising: [[Int]] = [
    [0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
]

let pawsFalling: [[Int]] = [
    [0, 0, 0, 0, 1, 3, 3, 1, 3, 3, 3, 1, 3, 1, 0, 0],
    [0, 0, 0, 0, 1, 3, 0, 0, 0, 0, 0, 1, 3, 1, 0, 0],
]

let pawsLand: [[Int]] = [
    [0, 0, 0, 1, 3, 3, 3, 1, 1, 3, 3, 3, 3, 1, 0, 0],
    [0, 0, 0, 1, 3, 3, 3, 1, 1, 3, 3, 3, 3, 1, 0, 0],
]

let pawsLandRecover: [[Int]] = [
    [0, 0, 0, 0, 1, 3, 3, 1, 3, 3, 3, 1, 3, 1, 0, 0],
    [0, 0, 0, 0, 0, 1, 3, 1, 1, 3, 3, 1, 3, 1, 0, 0],
]
