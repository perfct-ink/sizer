import Foundation

@main
struct SnapTests {
    /// Mirrors snapWindow's geometry without touching Accessibility.
    static func snap(_ w: CGRect, to snap: WindowSnap, visibleFrame v: CGRect, primaryH: CGFloat) -> CGRect {
        let size = snapEndSize(snap: snap, currentSize: w.size, visibleFrame: v)
        return CGRect(origin: axOrigin(snap: snap, size: size, visibleFrame: v, primaryH: primaryH), size: size)
    }

    static func main() {
        let primaryH: CGFloat = 900
        let v = CGRect(x: 0, y: 0, width: 1440, height: 875)   // visible frame, menu bar excluded
        var window = CGRect(x: 100, y: 120, width: 500, height: 400)

        window = snap(window, to: .center, visibleFrame: v, primaryH: primaryH)
        window = snap(window, to: .maximize, visibleFrame: v, primaryH: primaryH)
        let afterFirst = window
        precondition(afterFirst.size == v.size, "Maximize should fill the visible frame")

        window = snap(window, to: .maximize, visibleFrame: v, primaryH: primaryH)
        precondition(window.size == afterFirst.size,
                     "Second Maximize changed size: \(afterFirst.size) -> \(window.size)")
        precondition(window.origin == afterFirst.origin,
                     "Second Maximize moved window: \(afterFirst.origin) -> \(window.origin)")
        print("✓ Snap tests passed")
    }
}
