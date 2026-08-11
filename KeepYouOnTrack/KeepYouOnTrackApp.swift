//
//  KeepYouOnTrackApp.swift
//  KeepYouOnTrack
//
//  Created by Kacey Kim on 1/26/26.
//

import SwiftUI

@main
struct KeepYouOnTrackApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var permissionManager = PermissionManager.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // 노티피케이션 카테고리 등록
        NotificationService.shared.registerNotificationCategories()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if permissionManager.allPermissionsGranted {
                    MainPageView()
                } else {
                    PermissionRequestView()
                }
            }
            .onAppear {
                permissionManager.checkPermissions(force: true)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    permissionManager.checkPermissions(force: true)
                }
            }
        }
    }
}
