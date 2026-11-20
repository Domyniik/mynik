import Foundation
import Testing
@testable import Mynik

@MainActor
struct AppLockTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func locksOnlyWhenEnabledAndAfterGracePeriod() {
        #expect(!AppLock.shouldLock(isEnabled: false, backgroundedAt: start, now: start.addingTimeInterval(600)))
        #expect(!AppLock.shouldLock(isEnabled: true, backgroundedAt: nil, now: start))
        #expect(!AppLock.shouldLock(isEnabled: true, backgroundedAt: start, now: start.addingTimeInterval(10)))
        #expect(AppLock.shouldLock(isEnabled: true, backgroundedAt: start, now: start.addingTimeInterval(30)))
    }

    @Test func backgroundAndReturnFollowsSetting() throws {
        let defaults = try #require(UserDefaults(suiteName: "applock-\(UUID().uuidString)"))
        let lock = AppLock(defaults: defaults)
        #expect(!lock.isLocked)

        lock.setEnabled(true)
        lock.didEnterBackground(at: start)
        lock.didBecomeActive(at: start.addingTimeInterval(5))
        #expect(!lock.isLocked)

        lock.didEnterBackground(at: start)
        lock.didBecomeActive(at: start.addingTimeInterval(120))
        #expect(lock.isLocked)

        // Desligar desbloqueia logo.
        lock.setEnabled(false)
        #expect(!lock.isLocked)
        #expect(!lock.isEnabled)
    }
}
