//
//  AppDelegate.swift
//  KeepYouOnTrack
//
//  Created by Codex on 2/18/26.
//

import UIKit
import UserNotifications
import CoreFoundation

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let content = response.notification.request.content
        let shouldOpenManualInput =
            content.categoryIdentifier == "OPEN_IN_APP" ||
            (content.userInfo["openManualInput"] as? Bool == true)

        if shouldOpenManualInput {
            AppGroupManager.shared.requestManualInputScreen()
            let center = CFNotificationCenterGetDarwinNotifyCenter()
            CFNotificationCenterPostNotification(
                center,
                CFNotificationName("com.kacey.keepyouontrack.openManualInput" as CFString),
                nil,
                nil,
                true
            )
        }

        completionHandler()
    }
}
