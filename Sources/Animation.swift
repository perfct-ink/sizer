import Foundation

private func easeInOut(_ t: Double) -> Double {
    t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
}

/// Skip intermediate frames when synchronous AX requests cannot keep up.
/// Each animation owns its completion flag so app-wide snaps finish every window.
func scheduleAnimation(duration: TimeInterval, steps: Int, easedDeadlines: Bool = false,
                       update: @escaping (Double) -> Void) -> [DispatchWorkItem] {
    let started = ProcessInfo.processInfo.systemUptime
    let tolerance = max(0.03, duration * 0.5)
    var finished = false

    return (1...steps).map { step in
        let fraction = Double(step) / Double(steps)
        let progress = easeInOut(fraction)
        let scheduledElapsed = duration * (easedDeadlines ? progress : fraction)
        let item = DispatchWorkItem {
            guard !finished else { return }
            update(progress)
            if step == steps {
                finished = true
            } else if step >= 2,
                      ProcessInfo.processInfo.systemUptime - started > scheduledElapsed + tolerance {
                // Requests already in flight cannot be interrupted. Apply the final
                // frame once, then make all remaining queued callbacks no-ops.
                finished = true
                update(1)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + scheduledElapsed, execute: item)
        return item
    }
}
