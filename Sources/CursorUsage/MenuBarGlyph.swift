import AppKit

enum MenuBarGlyph {
    private static let cursorIcon: NSImage? = {
        if let url = Bundle.main.url(forResource: "CursorIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url)
        {
            return image
        }
        return NSImage(
            contentsOfFile: "/Applications/Cursor.app/Contents/Resources/Cursor.icns"
        )
    }()

    /// Horizontal menu-bar layout: `[icon] 14%  85%  13d`
    @MainActor
    static func image(
        cursorPercent: String,
        otherPercent: String,
        resetCountdown: String?
    ) -> NSImage {
        let barHeight = NSStatusBar.system.thickness
        let iconSide: CGFloat = 16
        let gap: CGFloat = 5
        let font = NSFont.menuBarFont(ofSize: 0) // system menu-bar size
        let textColor = menuBarTextColor()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
        ]
        let secondaryAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor.withAlphaComponent(0.85),
        ]

        let cursorText = NSAttributedString(string: cursorPercent, attributes: attrs)
        let apiText = NSAttributedString(string: otherPercent, attributes: attrs)
        let daysText = resetCountdown.map {
            NSAttributedString(string: $0, attributes: secondaryAttrs)
        }

        let cursorSize = cursorText.size()
        let apiSize = apiText.size()
        let daysSize = daysText?.size() ?? .zero

        var width = iconSide + gap + cursorSize.width + gap + apiSize.width
        if daysText != nil {
            width += gap + daysSize.width
        }
        width += 2 // trailing pad

        let size = NSSize(width: ceil(width), height: barHeight)

        let image = NSImage(size: size, flipped: false) { _ in
            let iconY = (barHeight - iconSide) / 2
            if let source = cursorIcon {
                source.draw(
                    in: NSRect(x: 0, y: iconY, width: iconSide, height: iconSide),
                    from: .zero,
                    operation: .sourceOver,
                    fraction: 1,
                    respectFlipped: true,
                    hints: [.interpolation: NSImageInterpolation.high]
                )
            }

            var x = iconSide + gap
            cursorText.draw(at: NSPoint(x: x, y: (barHeight - cursorSize.height) / 2))
            x += cursorSize.width + gap

            apiText.draw(at: NSPoint(x: x, y: (barHeight - apiSize.height) / 2))
            x += apiSize.width + gap

            if let daysText {
                daysText.draw(at: NSPoint(x: x, y: (barHeight - daysSize.height) / 2))
            }

            return true
        }

        image.isTemplate = false
        return image
    }

    @MainActor
    private static func menuBarTextColor() -> NSColor {
        let appearance = NSApp.effectiveAppearance
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? .white : .black
    }
}
