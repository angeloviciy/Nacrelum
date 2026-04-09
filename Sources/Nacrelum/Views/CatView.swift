import Cocoa

final class CatView: NSView {
    var lookDir: CGFloat = 0
    var legFrame = 0
    var bodyBob: CGFloat = 0
    var facingRight = true
    var isWalking = false
    var walkFacing: CGFloat = 0
    var legYBob: CGFloat = 0

    var eyeClose: CGFloat = 0
    var sitAmount: CGFloat = 0

    var currentLegs: [[Int]] = pawsIdle
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var armsRaised = false

    var tailWag: CGFloat = 0
    var haloBob: CGFloat = 0

    // Map grid values to colors: 0=empty, 1=outline, 2=earInner, 3=body, 4=shadow, 5=eye
    private func colorForValue(_ val: Int) -> CGColor? {
        switch val {
        case 1: return outlineColor.cgColor
        case 2: return earInnerColor.cgColor
        case 3: return bodyColor.cgColor
        case 4: return shadowColor.cgColor
        case 5: return eyeColor.cgColor
        default: return nil
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)
        ctx.setShouldAntialias(false)

        let s = SCALE
        let ox: CGFloat = 10 * s
        let oy: CGFloat = 4 * s
        let bb = bodyBob

        let bodyWidth: CGFloat = 16 * s
        let centerX = ox + bodyWidth / 2

        func px(_ col: CGFloat, _ row: CGFloat, w: CGFloat = s, h: CGFloat = s) -> CGRect {
            let rawX = ox + col * s
            let flippedX = facingRight ? rawX : (2 * centerX - rawX - w)
            return CGRect(x: flippedX, y: row, width: w, height: h)
        }

        let legs = currentLegs
        let lowestLegRow = legs.lastIndex { row in row.contains(where: { $0 != 0 }) } ?? max(0, legs.count - 1)
        let pivotX = bounds.width / 2
        let pivotY = oy - CGFloat(lowestLegRow + 1) * s
        ctx.saveGState()
        ctx.translateBy(x: pivotX, y: pivotY)
        ctx.scaleBy(x: scaleX, y: scaleY)
        ctx.translateBy(x: -pivotX, y: -pivotY)

        // ── Walking shadow ───────────────────────────────────────
        if isWalking && scaleX == 1 && scaleY == 1 {
            let shadowOffset = -walkFacing * s
            ctx.setFillColor(shadowColor.cgColor)

            for rowIndex in 0..<bodyGrid.count {
                let row = bodyGrid[rowIndex]
                guard let edgeCol = row.firstIndex(where: { $0 != 0 }) else { continue }
                let rect = px(CGFloat(edgeCol), oy + CGFloat(bodyGrid.count - 1 - rowIndex) * s + bb + legYBob)
                ctx.fill(rect.offsetBy(dx: shadowOffset, dy: 0).insetBy(dx: -0.5, dy: -0.5))
            }
        }

        // ── Legs (multi-value) ───────────────────────────────────
        for rowIndex in 0..<legs.count {
            for col in 0..<legs[rowIndex].count {
                let val = legs[rowIndex][col]
                guard val != 0, let color = colorForValue(val) else { continue }
                ctx.setFillColor(color)
                ctx.fill(px(CGFloat(col), oy - CGFloat(rowIndex + 1) * s).insetBy(dx: -0.5, dy: -0.5))
            }
        }

        // ── Body (multi-value grid) ──────────────────────────────
        // Skip value 5 (eyes) — drawn separately with animation
        for rowIndex in 0..<bodyGrid.count {
            for col in 0..<bodyGrid[rowIndex].count {
                let val = bodyGrid[rowIndex][col]
                guard val != 0 && val != 5 else { continue }
                guard let color = colorForValue(val) else { continue }
                ctx.setFillColor(color)
                ctx.fill(px(CGFloat(col), oy + CGFloat(bodyGrid.count - 1 - rowIndex) * s + bb + legYBob).insetBy(dx: -0.5, dy: -0.5))
            }
        }

        // ── Leg-to-body connector ────────────────────────────────
        if bb + legYBob > 0 {
            ctx.setFillColor(bodyColor.cgColor)
            for col in 0..<legs[0].count where legs[0][col] != 0 {
                ctx.fill(px(CGFloat(col), oy, w: s, h: bb + legYBob).insetBy(dx: -0.5, dy: 0))
            }
        }

        // ── Animated eyes (at grid value-5 positions: row 5, cols 10 and 13) ─
        let flip: CGFloat = facingRight ? 1 : -1
        let minimumEyeInset: CGFloat = 2
        let maxEyeShift = max(0, s - minimumEyeInset)
        let eyeShift = round(max(-1, min(1, lookDir)) * maxEyeShift) * flip
        let eyeRowY = oy + CGFloat(bodyGrid.count - 1 - 5) * s + bb + legYBob

        if eyeClose < 0.9 {
            // Open eyes: filled squares (matching the pixel art style)
            ctx.setFillColor(eyeColor.cgColor)
            ctx.fill(CGRect(x: px(10, 0).origin.x + eyeShift, y: eyeRowY, width: s, height: s))
            ctx.fill(CGRect(x: px(13, 0).origin.x + eyeShift, y: eyeRowY, width: s, height: s))
        } else {
            // Closed eyes: horizontal dash
            let dashHeight = max(1, s * 0.2)
            let dashY = eyeRowY + s / 2 - dashHeight / 2
            ctx.setFillColor(eyeColor.cgColor)
            ctx.fill(CGRect(x: px(10, 0).origin.x + eyeShift, y: dashY, width: s, height: dashHeight))
            ctx.fill(CGRect(x: px(13, 0).origin.x + eyeShift, y: dashY, width: s, height: dashHeight))
        }

        // ── Halo ─────────────────────────────────────────────────
        let haloBaseY = oy + CGFloat(bodyGrid.count) * s + 1 * s + haloBob + legYBob
        ctx.setFillColor(haloColor.cgColor)
        for rowIndex in 0..<haloGrid.count {
            for col in 0..<haloGrid[rowIndex].count where haloGrid[rowIndex][col] == 1 {
                ctx.fill(px(CGFloat(col), haloBaseY + CGFloat(haloGrid.count - 1 - rowIndex) * s).insetBy(dx: -0.5, dy: -0.5))
            }
        }

        ctx.restoreGState()
    }
}
