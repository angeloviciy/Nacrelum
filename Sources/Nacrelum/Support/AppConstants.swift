import Cocoa

let SCALE: CGFloat = 7

// ── Gold Cat Colors ──────────────────────────────────────────────
let bodyColor = NSColor(red: 0.91, green: 0.71, blue: 0.21, alpha: 1)      // Gold #E8B635
let shadowColor = NSColor(red: 0.77, green: 0.60, blue: 0.17, alpha: 1)    // Dark gold
let eyeColor = NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)          // White (star eyes)
let noseColor = NSColor(red: 0.55, green: 0.35, blue: 0.20, alpha: 1)      // Brown-pink
let haloColor = NSColor(red: 1.0, green: 0.95, blue: 0.60, alpha: 0.85)    // Pale glowing gold
let chestColor = NSColor(red: 0.96, green: 0.82, blue: 0.47, alpha: 1)     // Light gold chest

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

// ── Cat Body Grid (10 wide x 6 tall, multi-value) ───────────────
//   0 = empty, 1 = body (gold), 2 = chest (light gold),
//   3 = eye (drawn separately for animation), 4 = nose (brown-pink)
let bodyGrid: [[Int]] = [
    [0, 0, 1, 0, 0, 0, 0, 0, 0, 0],   // Row 0: ear tip
    [0, 1, 1, 1, 0, 0, 0, 0, 1, 0],   // Row 1: head + tail
    [0, 1, 3, 1, 1, 1, 1, 1, 1, 0],   // Row 2: head w/ eye, body extends
    [0, 1, 1, 1, 1, 1, 4, 1, 0, 0],   // Row 3: body w/ nose
    [0, 0, 1, 1, 1, 1, 1, 1, 0, 0],   // Row 4: body
    [0, 0, 1, 1, 1, 1, 1, 0, 0, 0],   // Row 5: lower body
]

// ── Halo Grid (10 wide x 3 tall, centered over head) ────────────
let haloGrid: [[Int]] = [
    [0, 1, 1, 1, 1, 0, 0, 0, 0, 0],
    [1, 0, 0, 0, 0, 1, 0, 0, 0, 0],
    [0, 1, 1, 1, 1, 0, 0, 0, 0, 0],
]

// ── Leg Grids (10 wide x 2 tall, 2 legs) ────────────────────────
let pawsIdle: [[Int]] = [
    [0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
    [0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
]

let pawsWalk: [[Int]] = [
    [0, 0, 0, 1, 0, 1, 0, 0, 0, 0],
    [0, 0, 0, 1, 0, 1, 0, 0, 0, 0],
]

let pawsSquish: [[Int]] = [
    [0, 1, 0, 0, 0, 0, 0, 1, 0, 0],
    [0, 1, 0, 0, 0, 0, 0, 1, 0, 0],
]

let pawsRising: [[Int]] = [
    [0, 0, 0, 1, 0, 1, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
]

let pawsFalling: [[Int]] = [
    [0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
    [0, 0, 1, 0, 0, 0, 0, 1, 0, 0],
]

let pawsLand: [[Int]] = [
    [0, 1, 0, 0, 0, 0, 0, 1, 0, 0],
    [0, 1, 0, 0, 0, 0, 0, 1, 0, 0],
]

let pawsLandRecover: [[Int]] = [
    [0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
    [0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
]
