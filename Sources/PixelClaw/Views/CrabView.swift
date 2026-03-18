import Cocoa

final class CrabView: NSView {
    var lookDir: CGFloat = 0
    var legFrame = 0
    var bodyBob: CGFloat = 0
    var facingRight = true
    var isWalking = false
    var walkFacing: CGFloat = 0
    var legYBob: CGFloat = 0

    var eyeClose: CGFloat = 0
    var sitAmount: CGFloat = 0

    var currentLegs: [[Int]] = legsIdle
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var armsRaised = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)
        ctx.setShouldAntialias(false)

        let s = SCALE
        let ox: CGFloat = 10 * s
        let oy: CGFloat = 4 * s
        let bb = bodyBob

        let bodyWidth = 10 * s
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

        if armsRaised {
            ctx.setFillColor(bodyColor.cgColor)
            let armTopY = oy + CGFloat(bodyGrid.count) * s + bb + legYBob
            ctx.fill(px(1, armTopY, w: s, h: 2 * s).insetBy(dx: -0.5, dy: -0.5))
            ctx.fill(px(8, armTopY, w: s, h: 2 * s).insetBy(dx: -0.5, dy: -0.5))
        }

        ctx.setFillColor(bodyColor.cgColor)
        for rowIndex in 0..<legs.count {
            for col in 0..<legs[rowIndex].count where legs[rowIndex][col] == 1 {
                ctx.fill(px(CGFloat(col), oy - CGFloat(rowIndex + 1) * s).insetBy(dx: -0.5, dy: -0.5))
            }
        }

        for rowIndex in 0..<bodyGrid.count {
            for col in 0..<bodyGrid[rowIndex].count where bodyGrid[rowIndex][col] == 1 {
                if armsRaised && rowIndex == 3 && (col == 0 || col == 9) {
                    continue
                }
                ctx.fill(px(CGFloat(col), oy + CGFloat(bodyGrid.count - 1 - rowIndex) * s + bb + legYBob).insetBy(dx: -0.5, dy: -0.5))
            }
        }

        if bb + legYBob > 0 {
            for col in 0..<legs[0].count where legs[0][col] == 1 {
                ctx.fill(px(CGFloat(col), oy, w: s, h: bb + legYBob).insetBy(dx: -0.5, dy: 0))
            }
        }

        ctx.setFillColor(eyeColor.cgColor)
        let flip: CGFloat = facingRight ? 1 : -1
        let minimumEyeInset: CGFloat = 2
        let maxEyeShift = max(0, s - minimumEyeInset)
        let eyeShift = round(max(-1, min(1, lookDir)) * maxEyeShift) * flip
        let eyeY = oy + CGFloat(bodyGrid.count - 1 - 1) * s + bb + legYBob
        let eyeHeight = max(1, s * (1 - eyeClose * 0.75))
        let eyeYOffset = (s - eyeHeight) / 2
        let leftEye = px(2, eyeY + eyeYOffset)
        let rightEye = px(7, eyeY + eyeYOffset)
        ctx.fill(CGRect(x: leftEye.origin.x + eyeShift, y: leftEye.origin.y, width: s, height: eyeHeight))
        ctx.fill(CGRect(x: rightEye.origin.x + eyeShift, y: rightEye.origin.y, width: s, height: eyeHeight))

        ctx.restoreGState()
    }
}
