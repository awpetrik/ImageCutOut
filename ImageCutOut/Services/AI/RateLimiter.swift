import Foundation

actor RateLimiter {
    private let limitPerMinute: Int
    private var timestamps: [Date] = []

    init(limitPerMinute: Int) {
        self.limitPerMinute = max(1, limitPerMinute)
    }

    func throttle() async {
        let now = Date()
        timestamps = timestamps.filter { now.timeIntervalSince($0) < 60 }
        if timestamps.count >= limitPerMinute {
            let earliest = timestamps.first ?? now
            let sleepTime = max(0.1, 60 - now.timeIntervalSince(earliest))
            try? await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))
        }
        timestamps.append(Date())
    }
}
