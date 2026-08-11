//
//  ShieldConfigurationProvider.swift
//  ShieldConfigurationExtension
//
//  Created by Kacey Kim on 1/26/26.
//

import ManagedSettings
import ManagedSettingsUI
import OSLog
import Foundation
import CoreFoundation
import UserNotifications
import UIKit

/// Shield Configuration Provider
/// 커스텀 Shield가 표시될 때 푸시 알림을 발송합니다.
class ShieldConfigurationProvider: ShieldConfigurationDataSource{

    private let logger = Logger(subsystem: "com.kacey.keepyouontrack.ShieldConfigurationExtension", category: "Shield")
    private let appGroupIdentifier = "group.com.kacey.keepyouontrack"

    // 알림 ID (중복 제거용)
    private let notificationIdentifier = "shield_purpose_input"
    private let accentColor = UIColor(
        named: "AccentColor"
    ) ?? UIColor(red: 141.0 / 255.0, green: 241.0 / 255.0, blue: 220.0 / 255.0, alpha: 1.0)
    private let backgroundBlack = UIColor(red: 0.03, green: 0.03, blue: 0.035, alpha: 1.0)

    override init() {
        super.init()
        logger.info("🛡️ ShieldConfigurationProvider: INIT CALLED - Extension loaded!")
        print("🛡️ ShieldConfigurationProvider: INIT CALLED - Extension loaded!")
    }

    /// Shield 설정
    /// ShieldConfigurationDataSource 프로토콜의 필수 메서드
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        logger.info("🛡️ ShieldConfigurationProvider: configuration called for application")
        logger.info("🛡️ ShieldConfigurationProvider: Application bundle ID: \(application.bundleIdentifier ?? "unknown")")
        logger.info("🛡️ ShieldConfigurationProvider: Extension Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print("🛡️ ShieldConfigurationProvider: configuration called - START")
        // 자동 발송은 일단 보류. 현재 배포 플로우는 쉴드 버튼 액션(ShieldActionExtension)에서만 알림을 보냅니다.
        // 필요 시 아래 한 줄을 다시 활성화하면 표시 시점 자동 알림도 동작합니다.
        // scheduleNotificationOnce(source: "shield_display")

        // 커스텀 Shield 설정
        let config = ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: backgroundBlack,
            icon: UIImage(systemName: "eye.fill"),
            title: ShieldConfiguration.Label(text: "앱이 잠금되었습니다", color: .white),
            subtitle: ShieldConfiguration.Label(text: "목적을 입력하고 앱을 사용하세요", color: .white),
            primaryButtonLabel: ShieldConfiguration.Label(text: "목적 입력하고 앱 사용하기", color: .white),
            primaryButtonBackgroundColor: accentColor,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "닫기", color: .white)
        )

        logger.info("🛡️ ShieldConfigurationProvider: configuration completed successfully")
        print("🛡️ ShieldConfigurationProvider: configuration called - END")

        return config
    }

    private func scheduleNotificationOnce(source: String) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        guard defaults.bool(forKey: "notificationAuthorized") else { return }

        let now = Date()
        let throttleWindow: TimeInterval = 5
        let lastScheduledKey = "lastNotificationScheduledTimestamp"

        if let lastScheduled = defaults.object(forKey: lastScheduledKey) as? Date,
           now.timeIntervalSince(lastScheduled) < throttleWindow {
            logger.info("⏭️ ShieldConfigurationProvider: Notification throttled")
            return
        }

        defaults.set(now, forKey: lastScheduledKey)

        let content = UNMutableNotificationContent()
        content.title = "목적을 입력하세요"
        content.body = "알림을 눌러 앱에서 목적과 시간을 입력하세요"
        content.sound = .default
        content.categoryIdentifier = "OPEN_IN_APP"
        content.userInfo = ["route": "shield_event", "source": source, "openManualInput": true]

        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        UNUserNotificationCenter.current().add(request) { [logger] error in
            if let error = error {
                logger.error("❌ ShieldConfigurationProvider: Failed to schedule notification: \(error.localizedDescription)")
            } else {
                logger.info("✅ ShieldConfigurationProvider: Notification scheduled from \(source)")
            }
        }
    }
}
