import Foundation
import CoreGraphics

enum WindowSnap {
    case left, right, top, bottom                       // halves  (⌃⌥⌘+arrow)
    case topLeft, topRight, bottomLeft, bottomRight     // quarters (⌃⌥⇧+arrow)
    case maximize                                        // ⌃⌥⌘M
    case center                                          // ⌃⌥⌘C – 75% of visible frame
    case center50                                        // ⌃⌥X  – 50% of visible frame
}

/// AX origin (top-left corner, y downward) for a window of `size` placed at `snap`
/// inside `v` (NS visible frame, bottom-left origin).
///
/// Each snap position has a fixed anchor corner/edge that stays at the screen
/// boundary even when `size` is clamped by the window's minimum-size constraint.
func axOrigin(snap: WindowSnap, size s: CGSize, visibleFrame v: CGRect, primaryH: CGFloat) -> CGPoint {
    let topAX    = primaryH - v.maxY
    let bottomAX = primaryH - (v.minY + s.height)
    let rightX   = v.maxX - s.width

    switch snap {
    case .left:        return CGPoint(x: v.minX, y: topAX)
    case .right:       return CGPoint(x: rightX, y: topAX)
    case .top:         return CGPoint(x: v.minX, y: topAX)
    case .bottom:      return CGPoint(x: v.minX, y: bottomAX)
    case .topLeft:     return CGPoint(x: v.minX, y: topAX)
    case .topRight:    return CGPoint(x: rightX, y: topAX)
    case .bottomLeft:  return CGPoint(x: v.minX, y: bottomAX)
    case .bottomRight: return CGPoint(x: rightX, y: bottomAX)
    case .maximize:    return CGPoint(x: v.minX, y: topAX)
    case .center:
        return CGPoint(x: v.minX + (v.width - s.width) / 2,
                       y: primaryH - v.midY - s.height / 2)
    case .center50:
        return CGPoint(x: v.minX + (v.width - s.width) / 2,
                       y: primaryH - v.midY - s.height / 2)
    }
}

func desiredSize(for snap: WindowSnap, visibleFrame v: CGRect) -> CGSize {
    switch snap {
    case .left, .right:      return CGSize(width: v.width / 2, height: v.height)
    case .top, .bottom:      return CGSize(width: v.width,     height: v.height / 2)
    case .topLeft, .topRight,
         .bottomLeft, .bottomRight:
                              return CGSize(width: v.width / 2, height: v.height / 2)
    case .maximize:          return CGSize(width: v.width,     height: v.height)
    case .center:            return CGSize(width: v.width * 0.75, height: v.height * 0.75)
    case .center50:          return CGSize(width: v.width * 0.50, height: v.height * 0.50)
    }
}

/// The size a snap should end at: the current size if it already matches the
/// desired size (within 2pt), otherwise the desired size.
func snapEndSize(snap: WindowSnap, currentSize: CGSize, visibleFrame v: CGRect) -> CGSize {
    let desired = desiredSize(for: snap, visibleFrame: v)
    if abs(currentSize.width - desired.width) <= 2 && abs(currentSize.height - desired.height) <= 2 {
        return currentSize
    }
    return desired
}
