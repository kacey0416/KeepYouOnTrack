//
//  DeviceActivityMonitorExtension.swift
//  DeviceActivityMonitorExtension
//
//  Created by Kacey Kim on 1/26/26.
//

import DeviceActivity
import FamilyControls
import ManagedSettings
import ActivityKit
import OSLog
import CoreFoundation

/// DeviceActivityCenter 모니터링
/// 임시 잠금해제 세션 종료 시 쉴드를 재적용합니다.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let logger = Logger(subsystem: "com.kacey.keepyouontrack.DeviceActivityMonitorExtension", category: "Monitor")
    private let unlockActivityNamePrefix = "temporaryUnlockSession."
    private let appGroupIdentifier = "group.com.kacey.keepyouontrack"
    private let lockedSelectionKey = "lockedSelection"
    private let activeSessionKey = "activeSession"
    private let activeSessionIdentifierKey = "activeSessionIdentifier"

    /// 스케줄 구간 시작 시 호출
    override func intervalDidStart(for activity: DeviceActivityName) {
        logger.info("🔔 DeviceActivityMonitorExtension: intervalDidStart called for \(activity.rawValue)")
    }

    /// 15분보다 짧은 세션도 background에서 정확한 만료 시각에 재잠금하기 위한 callback입니다.
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        logger.info("🔔 DeviceActivityMonitorExtension: intervalWillEndWarning called for \(activity.rawValue)")
        relockIfCurrentSession(for: activity)
    }

    /// 스케줄 구간 종료 시 호출
    override func intervalDidEnd(for activity: DeviceActivityName) {
        logger.info("🔔 DeviceActivityMonitorExtension: intervalDidEnd called for \(activity.rawValue)")
        relockIfCurrentSession(for: activity)
    }

    private func relockIfCurrentSession(for activity: DeviceActivityName) {
        guard let sessionId = sessionIdentifier(from: activity) else { return }
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              defaults.string(forKey: activeSessionIdentifierKey) == sessionId else {
            logger.info("⏭️ DeviceActivityMonitorExtension: Ignoring stale session callback")
            return
        }
        guard let data = defaults.data(forKey: lockedSelectionKey),
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) else {
            logger.error("❌ DeviceActivityMonitorExtension: Failed to load persisted selection")
            return
        }

        let applications = Set(selection.applicationTokens)
        let store = ManagedSettingsStore()
        store.shield.applications = applications.isEmpty ? nil : applications
        store.shield.applicationCategories = nil
        defaults.removeObject(forKey: activeSessionKey)
        defaults.removeObject(forKey: activeSessionIdentifierKey)
        DeviceActivityCenter().stopMonitoring([activity])
        Task {
            await endAllSessionActivities()
        }
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("com.kacey.keepyouontrack.sessionEnded" as CFString),
            nil,
            nil,
            true
        )
        logger.info("✅ DeviceActivityMonitorExtension: Shield relocked from persisted selection")
    }

    private func sessionIdentifier(from activity: DeviceActivityName) -> String? {
        guard activity.rawValue.hasPrefix(unlockActivityNamePrefix) else { return nil }
        let identifier = activity.rawValue.dropFirst(unlockActivityNamePrefix.count)
        return identifier.isEmpty ? nil : String(identifier)
    }

    @available(iOS 16.1, *)
    private func endAllSessionActivities() async {
        for activity in Activity<SessionLiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        logger.info("✅ DeviceActivityMonitorExtension: Live activities ended")
    }
}
