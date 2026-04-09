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

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)
        ctx.setShouldAntialias(false)

        let s = SCALE
        let ox: CGFloat = 10 * s
        let oy: CGFloat = 4 * s
        let bb = bodyBob

        let bodyWidth: CGFloat = 10 * s
        let centerX = ox + bodyWidth / 2

        func px(_ col: CGFloat, _ row: CGFloat, w: CGFloat = s, h: CGFloat = s) -> CGRect {
            let rawX = ox + col * s
            let flippedX = facingRight ? rawX : (2 * centerX - rawX - w)
            return CGRect(x: flippedX, y: row, width: w, height: h)
        }

        let legs = currentLegs
        let lowestLegRow = legs.lastIndex { $0.contains(1) } ?? max(0, legs.count - 1)
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
                guard let edgeCol = row.firstIndex(of: 1) else { continue }
                let rect = px(CGFloat(edgeCol), oy + CGFloat(bodyGrid.count - 1 - rowIndex) * s + bb + legYBob)
                ctx.fill(rect.offsetBy(dx: shadowOffset, dy: 0).insetBy(dx: -0.5, dy: -0.5))
            }

            if bb + legYBob > 0, let edgeCol = legs[0].firstIndex(of: 1) {
                let rect = px(CGFloat(edgeCol), oy, w: s, h: bb + legYBob)
                ctx.fill(rect.offsetBy(dx: shadowOffset, dy: 0).insetBy(dx: -0.5, dy: 0))
            }

            let cols = legs[0].count
            var trailingColumn = -1
            for col in 0..<cols where legs[0][col] == 1 {
                trailingColumn = col
                break
            }
            if trailingColumn >= 0 {
                for rowIndex in 0..<legs.count where legs[rowIndex][trailingColumn] == 1 {
                    let rect = px(CGFloat(trailingColumn), oy - CGFloat(rowIndex + 1) * s)
                    ctx.fill(rect.offsetBy(dx: shadowOffset, dy: 0).insetBy(dx: -0.5, dy: -0.5))
                }
            }
        }

        // ── Arms raised (celebration) ────────────────────────────
        if armsRaised {
            ctx.setFillColor(bodyColor.cgColor)
            let armTopY = oy + CGFloat(bodyGrid.count) * s + bb + legYBob
            // Raise ear tips higher
            ctx.fill(px(5, armTopY, w: s, h: 2 * s).insetBy(dx: -0.5, dy: -0.5))
            ctx.fill(px(7, armTopY, w: s, h: 2 * s).insetBy(dx: -0.5, dy: -0.5))
        }

        // ── Legs ─────────────────────────────────────────────────
        ctx.setFillColor(bodyColor.cgColor)
        for rowIndex in 0..<legs.count {
            for col in 0..<legs[rowIndex].count where legs[rowIndex][col] == 1 {
                ctx.fill(px(CGFloat(col), oy - CGFloat(rowIndex + 1) * s).insetBy(dx: -0.5, dy: -0.5))
            }
        }

        // ── Body ─────────────────────────────────────────────────
        for rowIndex in 0..<bodyGrid.count {
            for col in 0..<bodyGrid[rowIndex].count where bodyGrid[rowIndex][col] == 1 {
                if armsRaised && rowIndex == 0 && (col == 5 || col == 7) {
                    continue
                }
                ctx.fill(px(CGFloat(col), oy + CGFloat(bodyGrid.count - 1 - rowIndex) * s + bb + legYBob).insetBy(dx: -0.5, dy: -0.5))
            }
        }

        // ── Leg-to-body connector ────────────────────────────────
        if bb + legYBob > 0 {
            for col in 0..<legs[0].count where legs[0][col] == 1 {
                ctx.fill(px(CGFloat(col), oy, w: s, h: bb + legYBob).insetBy(dx: -0.5, dy: 0))
            }
        }

        // ── Inner ears ───────────────────────────────────────────
        // Ear tips at row 0 cols 5,7 — inner ear is on the inside edge
        let earRow = oy + CGFloat(bodyGrid.count - 1 - 0) * s + bb + legYBob
        ctx.setFillColor(earInnerColor.cgColor)
        ctx.fill(px(6, earRow).insetBy(dx: -0.5, dy: -0.5))

        // ── Star eyes ────────────────────────────────────────────
        // Eyes on row 2 (the widest head row), at cols 5 and 7
        let flip: CGFloat = facingRight ? 1 : -1
        let minimumEyeInset: CGFloat = 2
        let maxEyeShift = max(0, s - minimumEyeInset)
        let eyeShift = round(max(-1, min(1, lookDir)) * maxEyeShift) * flip
        let eyeRowY = oy + CGFloat(bodyGrid.count - 1 - 2) * s + bb + legYBob

        if eyeClose < 0.9 {
            let starScale = s * (1 - eyeClose * 0.5)
            drawStarEye(ctx: ctx, centerX: px(5, 0).origin.x + eyeShift + s / 2, centerY: eyeRowY + s / 2, size: starScale)
            drawStarEye(ctx: ctx, centerX: px(7, 0).origin.x + eyeShift + s / 2, centerY: eyeRowY + s / 2, size: starScale)
        } else {
            // Closed eyes: horizontal dash
            let dashHeight = max(1, s * 0.15)
            let dashY = eyeRowY + s / 2 - dashHeight / 2
            ctx.setFillColor(eyeColor.cgColor)
            ctx.fill(CGRect(x: px(5, 0).origin.x + eyeShift, y: dashY, width: s, height: dashHeight))
            ctx.fill(CGRect(x: px(7, 0).origin.x + eyeShift, y: dashY, width: s, height: dashHeight))
        }

        // ── Nose ─────────────────────────────────────────────────
        // Small dot on lower head (row 3), between the eyes
        let noseRowY = oy + CGFloat(bodyGrid.count - 1 - 3) * s + bb + legYBob
        ctx.setFillColor(noseColor.cgColor)
        let noseSize = s * 0.4
        let noseCX = px(6, 0).origin.x + s / 2 - noseSize / 2
        ctx.fill(CGRect(x: noseCX, y: noseRowY + s * 0.3, width: noseSize, height: noseSize))

        // ── Tail ─────────────────────────────────────────────────
        // Tail extends from the back (left side when facing right)
        ctx.setFillColor(bodyColor.cgColor)
        let tailBaseCol: CGFloat = facingRight ? 0 : CGFloat(bodyGrid[0].count - 1)
        let tailDir: CGFloat = facingRight ? -1 : 1
        // Tail starts at body level (row 5-6 area), curving upward
        let tailBaseY = oy + CGFloat(bodyGrid.count - 1 - 5) * s + bb + legYBob
        let wagOffset = round(tailWag * s * 0.7)
        ctx.fill(px(tailBaseCol, tailBaseY + s * 0.5).insetBy(dx: -0.5, dy: -0.5))
        ctx.fill(px(tailBaseCol + tailDir, tailBaseY + s * 1.0 + wagOffset).insetBy(dx: -0.5, dy: -0.5))
        ctx.fill(px(tailBaseCol + tailDir * 2, tailBaseY + s * 1.5 + wagOffset * 1.3).insetBy(dx: -0.5, dy: -0.5))

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

    private func drawStarEye(ctx: CGContext, centerX: CGFloat, centerY: CGFloat, size: CGFloat) {
        ctx.setFillColor(eyeColor.cgColor)
        let half = size / 2
        let quarter = size / 4
        // Vertical arm of 4-pointed star
        ctx.fill(CGRect(x: centerX - quarter, y: centerY - half, width: half, height: size))
        // Horizontal arm of 4-pointed star
        ctx.fill(CGRect(x: centerX - half, y: centerY - quarter, width: size, height: half))
    }
}
