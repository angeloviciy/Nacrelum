import Cocoa

let SCALE: CGFloat = 7

// ── Gold Cat Colors ──────────────────────────────────────────────
let bodyColor = NSColor(red: 0.91, green: 0.71, blue: 0.21, alpha: 1)      // Gold
let shadowColor = NSColor(red: 0.77, green: 0.60, blue: 0.17, alpha: 1)    // Dark gold
let eyeColor = NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)          // White (star eyes)
let bellyColor = NSColor(red: 1.0, green: 0.85, blue: 0.78, alpha: 1)      // Light pink belly patch
let haloColor = NSColor(red: 1.0, green: 0.95, blue: 0.60, alpha: 0.85)    // Pale glowing gold
let chestColor = NSColor(red: 0.96, green: 0.82, blue: 0.47, alpha: 1)     // Light gold

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
//   HEAD ON RIGHT so it leads when facingRight=true.
//   px() mirrors everything when facingRight=false → head still leads.
//   0=empty, 1=body(gold), 3=eye(animated), 4=belly(light pink)
let bodyGrid: [[Int]] = [
    [0, 1, 0, 0, 0, 0, 0, 1, 1, 0],   // Row 0: tail tip (curled up) + ear (2px)
    [0, 1, 0, 0, 0, 1, 1, 1, 1, 0],   // Row 1: tail base + head top (4px wide)
    [0, 1, 1, 1, 1, 1, 1, 3, 1, 0],   // Row 2: body + eye at col 7
    [0, 0, 1, 1, 1, 1, 1, 1, 1, 0],   // Row 3: body
    [0, 0, 1, 1, 1, 1, 1, 1, 0, 0],   // Row 4: body
    [0, 0, 0, 1, 4, 4, 1, 0, 0, 0],   // Row 5: lower body + belly patch (cols 4-5)
]

// ── Halo Grid (10 wide x 3 tall, centered over head/right side) ─
let haloGrid: [[Int]] = [
    [0, 0, 0, 0, 0, 1, 1, 1, 1, 0],
    [0, 0, 0, 0, 1, 0, 0, 0, 0, 1],
    [0, 0, 0, 0, 0, 1, 1, 1, 1, 0],
]

// ── Leg Grids (10 wide x 2 tall, 2 legs) ────────────────────────
//   Back leg under body (col 3), front leg under head (col 7)
let pawsIdle: [[Int]] = [
    [0, 0, 0, 1, 0, 0, 0, 1, 0, 0],
    [0, 0, 0, 1, 0, 0, 0, 1, 0, 0],
]

let pawsWalk: [[Int]] = [
    [0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
    [0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
]

let pawsSquish: [[Int]] = [
    [0, 1, 0, 0, 0, 0, 0, 0, 1, 0],
    [0, 1, 0, 0, 0, 0, 0, 0, 1, 0],
]

let pawsRising: [[Int]] = [
    [0, 0, 0, 1, 0, 0, 1, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
]

let pawsFalling: [[Int]] = [
    [0, 0, 0, 1, 0, 0, 0, 1, 0, 0],
    [0, 0, 0, 1, 0, 0, 0, 0, 1, 0],
]

let pawsLand: [[Int]] = [
    [0, 1, 0, 0, 0, 0, 0, 0, 1, 0],
    [0, 1, 0, 0, 0, 0, 0, 0, 1, 0],
]

let pawsLandRecover: [[Int]] = [
    [0, 0, 0, 1, 0, 0, 0, 1, 0, 0],
    [0, 0, 0, 1, 0, 0, 0, 1, 0, 0],
]
