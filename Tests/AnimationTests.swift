import Foundation

@main
struct AnimationTests {
    static func drainQueue() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    }

    static func main() {
        for eased in [false, true] {
            var normalFrames: [Double] = []
            _ = scheduleAnimation(duration: 0.15, steps: 8, easedDeadlines: eased) {
                normalFrames.append($0)
            }
            drainQueue()
            precondition(normalFrames.count == 8 && normalFrames.last == 1,
                         "Responsive animations should run every frame")

            var slowFrames: [Double] = []
            _ = scheduleAnimation(duration: 0.06, steps: 12, easedDeadlines: eased) {
                slowFrames.append($0)
                if slowFrames.count == 2 { Thread.sleep(forTimeInterval: 0.08) }
            }
            drainQueue()
            precondition(slowFrames.count == 3 && slowFrames.last == 1,
                         "Slow animations should jump to the target after step two")
        }

        var cancelledFrames = 0
        let cancelled = scheduleAnimation(duration: 0.06, steps: 12) { _ in
            cancelledFrames += 1
        }
        cancelled.forEach { $0.cancel() }
        drainQueue()
        precondition(cancelledFrames == 0, "Cancelled animations must not apply a final frame")

        var firstFrames: [Double] = []
        var secondFrames: [Double] = []
        _ = scheduleAnimation(duration: 0.06, steps: 12) {
            firstFrames.append($0)
            if firstFrames.count == 2 { Thread.sleep(forTimeInterval: 0.08) }
        }
        _ = scheduleAnimation(duration: 0.06, steps: 12) { secondFrames.append($0) }
        drainQueue()
        precondition(firstFrames.count == 3 && firstFrames.last == 1)
        precondition(secondFrames.count == 3 && secondFrames.last == 1,
                     "Concurrent window animations must each reach their target")
        print("✓ Animation tests passed")
    }
}
