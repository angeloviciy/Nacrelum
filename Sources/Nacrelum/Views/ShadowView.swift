import Cocoa

final class ShadowView: NSView {
    var facingRight = true
    var legRows = 3

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)
        ctx.setShouldAntialias(false)

        let s = SCALE
        let ox: CGFloat = 10 * s
        let oy: CGFloat = 4 * s + SHADOW_FLOOR_MARGIN
        let bodyWidth: CGFloat = 10 * s
        let centerX = ox + bodyWidth / 2
        let rows = max(1, legRows)

        let shadowWidth = 8 * s
        let shadowX = facingRight ? (ox + s) : (2 * centerX - ox - s - shadowWidth)
        ctx.setFillColor(NSColor(red: 0.15, green: 0.12, blue: 0.0, alpha: 0.10).cgColor)
        ctx.fill(CGRect(x: shadowX, y: oy - CGFloat(rows + 1) * s - 2, width: shadowWidth, height: s))
        ctx.setFillColor(NSColor(red: 0.50, green: 0.40, blue: 0.10, alpha: 0.10).cgColor)
        ctx.fill(CGRect(x: shadowX, y: oy - CGFloat(rows) * s - 2, width: shadowWidth, height: s))
    }
}
