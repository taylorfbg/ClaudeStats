import AppKit

enum ClaudeIcon {
    static func menuBarImage() -> NSImage {
        if let image = NSImage(named: "ClaudeIcon") {
            // Resize to fit menu bar height (18pt)
            let targetHeight: CGFloat = 18
            let aspectRatio = image.size.width / image.size.height
            let targetWidth = targetHeight * aspectRatio
            let resized = NSImage(size: NSSize(width: targetWidth, height: targetHeight))
            resized.lockFocus()
            image.draw(
                in: NSRect(x: 0, y: 0, width: targetWidth, height: targetHeight),
                from: NSRect(origin: .zero, size: image.size),
                operation: .copy,
                fraction: 1.0
            )
            resized.unlockFocus()
            resized.isTemplate = false
            return resized
        }
        // Fallback to SF Symbol
        return NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "Claude Stats")!
    }
}
