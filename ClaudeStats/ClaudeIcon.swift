import AppKit

enum ClaudeIcon {
    static func menuBarImage() -> NSImage {
        if let image = NSImage(named: "ClaudeIcon") {
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
        return NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "Claude Stats")!
    }

    static func menuBarImage(badgeCount: Int) -> NSImage {
        let baseImage = menuBarImage()
        guard badgeCount > 0 else { return baseImage }

        let badgeSize: CGFloat = 12
        let totalWidth = baseImage.size.width + badgeSize * 0.4
        let totalHeight = max(baseImage.size.height, badgeSize + 2)

        let composite = NSImage(size: NSSize(width: totalWidth, height: totalHeight))
        composite.lockFocus()

        // Draw base icon centered vertically
        let iconY = (totalHeight - baseImage.size.height) / 2
        baseImage.draw(
            in: NSRect(x: 0, y: iconY, width: baseImage.size.width, height: baseImage.size.height),
            from: .zero,
            operation: .copy,
            fraction: 1.0
        )

        // Draw badge circle at top-right
        let badgeX = baseImage.size.width - badgeSize * 0.6
        let badgeY = totalHeight - badgeSize - 1
        let badgeRect = NSRect(x: badgeX, y: badgeY, width: badgeSize, height: badgeSize)

        NSColor.systemOrange.setFill()
        NSBezierPath(ovalIn: badgeRect).fill()

        // Draw count text
        let text = "\(badgeCount)"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let textSize = text.size(withAttributes: attrs)
        let textX = badgeRect.midX - textSize.width / 2
        let textY = badgeRect.midY - textSize.height / 2
        text.draw(at: NSPoint(x: textX, y: textY), withAttributes: attrs)

        composite.unlockFocus()
        composite.isTemplate = false
        return composite
    }
}
