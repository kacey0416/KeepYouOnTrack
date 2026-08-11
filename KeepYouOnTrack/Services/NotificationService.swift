//
//  NotificationService.swift
//  KeepYouOnTrack
//
//  Created by Kacey Kim on 1/26/26.
//

import Foundation
import UserNotifications

/// 노티피케이션 서비스
/// 노티피케이션 카테고리 등록 및 관리
class NotificationService {
    static let shared = NotificationService()

    private init() {}

    /// 노티피케이션 카테고리 등록
    func registerNotificationCategories() {
        let center = UNUserNotificationCenter.current()

        let openInAppCategory = UNNotificationCategory(
            identifier: "OPEN_IN_APP",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        center.setNotificationCategories([openInAppCategory])
    }
}
