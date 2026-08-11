//
//  ShieldActionExtension.swift
//  ShieldActionExtension
//
//  Created by Kacey Kim on 1/28/26.
//
// ShieldActionExtension.swift

import ManagedSettings
import FamilyControls
import UserNotifications
import OSLog
import Foundation

class ShieldActionExtension: ShieldActionDelegate {

    private let logger = Logger(subsystem: "com.kacey.keepyouontrack.ShieldActionExtension", category: "ShieldAction")
    private let appGroupIdentifier = "group.com.kacey.keepyouontrack"
    private let notificationIdentifier = "shield_purpose_input"
    private let pendingUnlockSelectionKey = "pendingUnlockSelection"

    // 앱 단위 액션 처리
    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        logger.info("🛡️ ShieldActionExtension: handle(action:for application:) called - \(String(describing: action))")

        switch action {
        case .primaryButtonPressed:
            // 옵션1/2 모두 푸시를 보내고 쉴드는 유지
            savePendingUnlockSelection(application: application)
            scheduleFlowNotification()
            completionHandler(.defer)

        case .secondaryButtonPressed:
            // 두 번째 버튼: Shield 닫기
            completionHandler(.close)

        @unknown default:
            completionHandler(.close)
        }
    }

    // 웹 도메인 / 카테고리 쪽은 필요하면 동일 패턴 적용, 지금은 단순 close
    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.close)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.close)
    }

    /// 알림 스케줄링 (중복 방지 포함) – Shield 버튼 액션용
    private func scheduleFlowNotification() {
        let source = "shield_button_app_input_mode"
        logger.info("🔔 ShieldActionExtension: scheduleFlowNotification called, source = \(source)")

        guard let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            logger.error("❌ ShieldActionExtension: Failed to get App Group UserDefaults")
            return
        }

        guard appGroupDefaults.bool(forKey: "notificationAuthorized") else {
            logger.warning("⚠️ ShieldActionExtension: Notification not authorized")
            return
        }

        let notificationCenter = UNUserNotificationCenter.current()
        // 비동기 조회 후 이어서 스케줄링한다. (확장 스레드 블로킹 방지)
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let hasPendingNotification = requests.contains { $0.identifier == self.notificationIdentifier }
            self.scheduleFlowNotificationRequest(
                hasPendingNotification: hasPendingNotification,
                notificationCenter: notificationCenter,
                appGroupDefaults: appGroupDefaults,
                source: source,
                categoryIdentifier: "OPEN_IN_APP"
            )
        }
    }

    private func scheduleFlowNotificationRequest(
        hasPendingNotification: Bool,
        notificationCenter: UNUserNotificationCenter,
        appGroupDefaults: UserDefaults,
        source: String,
        categoryIdentifier: String
    ) {
        let throttleWindow: TimeInterval = 5 // 버튼 중복 클릭 방지를 위해 5초로 단축
        let now = Date()
        let lastScheduledKey = "lastNotificationScheduledTimestamp"

        // Pending 알림이 없으면 throttle 무시 (알림을 지웠을 수 있음)
        // Pending 알림이 있으면 throttle 체크 (중복 클릭 방지)
        if hasPendingNotification {
            if let lastScheduled = appGroupDefaults.object(forKey: lastScheduledKey) as? Date {
                let timeSinceLastScheduled = now.timeIntervalSince(lastScheduled)
                if timeSinceLastScheduled < throttleWindow {
                    logger.info("⏭️ ShieldActionExtension: Skipping notification (throttled, last scheduled \(Int(timeSinceLastScheduled))s ago, pending notification exists)")
                    return
                }
            }
        } else {
            logger.info("ℹ️ ShieldActionExtension: No pending notification found, sending new notification regardless of throttle")
        }

        // 마지막 스케줄링 시간 업데이트
        appGroupDefaults.set(now, forKey: lastScheduledKey)

        // 기존 알림 제거 (같은 ID로 중복 방지)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "목적을 입력하세요"
        content.body = "알림을 눌러 앱에서 목적과 시간을 입력하세요"
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = ["route": "shield_event", "source": source, "openManualInput": true]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { [logger] error in
            if let error = error {
                logger.error("❌ ShieldActionExtension: Failed to schedule notification: \(error.localizedDescription)")
            } else {
                logger.info("✅ ShieldActionExtension: Notification scheduled successfully")
            }
        }
    }

    private func savePendingUnlockSelection(application: ApplicationToken) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        var selection = FamilyActivitySelection()
        selection.applicationTokens = Set([application])

        guard let data = try? PropertyListEncoder().encode(selection) else { return }
        defaults.set(data, forKey: pendingUnlockSelectionKey)
    }

}
