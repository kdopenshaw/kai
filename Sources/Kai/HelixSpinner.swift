import AppKit

final class HelixSpinner: NSView {
    private var timer: Timer?
    private var phase: CGFloat = 0

    private static let cyan = NSColor(red: 0.404, green: 0.718, blue: 0.812, alpha: 1.0)
    private static let pink = NSColor(red: 0.812, green: 0.400, blue: 0.600, alpha: 1.0)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }

    func start() {
        stop()
        let t = Timer(timeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.phase += 0.32
            self.needsDisplay = true
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    override func draw(_ dirtyRect: NSRect) {
        let pixel: CGFloat = 3
        let cols = 13
        let rows = 7
        let gridW = CGFloat(cols) * pixel
        let gridH = CGFloat(rows) * pixel
        let originX = (bounds.width - gridW) / 2
        let originY = (bounds.height - gridH) / 2
        let centerRow = CGFloat(rows - 1) / 2.0
        let amplitude = CGFloat(rows - 1) / 2.0
        let turns: CGFloat = 2.2

        for col in 0..<cols {
            let t = CGFloat(col) / CGFloat(cols - 1)
            let angle = t * .pi * turns + phase
            let r1 = centerRow + sin(angle) * amplitude
            let r2 = centerRow + sin(angle + .pi) * amplitude
            let d1 = (cos(angle) + 1) / 2
            let d2 = (cos(angle + .pi) + 1) / 2

            let row1 = Int(r1.rounded())
            let row2 = Int(r2.rounded())

            drawPixel(row: row1, col: col, originX: originX, originY: originY,
                      pixel: pixel, color: Self.cyan, depth: d1)
            drawPixel(row: row2, col: col, originX: originX, originY: originY,
                      pixel: pixel, color: Self.pink, depth: d2)
        }
    }

    private func drawPixel(row: Int, col: Int, originX: CGFloat, originY: CGFloat,
                           pixel: CGFloat, color: NSColor, depth: CGFloat) {
        let alpha = 0.25 + depth * 0.75
        color.withAlphaComponent(alpha).setFill()
        let rect = NSRect(
            x: originX + CGFloat(col) * pixel,
            y: originY + CGFloat(row) * pixel,
            width: pixel,
            height: pixel
        )
        rect.fill()
    }
}
