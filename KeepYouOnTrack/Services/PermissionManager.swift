//
//  PermissionManager.swift
//  KeepYouOnTrack
//
//  Created by Kacey Kim on 1/26/26.
//

import Foundation
import FamilyControls
import UserNotifications
import UIKit

/// 필수 권한 관리 서비스
/// Family Controls 및 노티피케이션 권한을 요청하고 검증합니다.
@MainActor
class PermissionManager: ObservableObject {
    static let shared = PermissionManager()

    @Published var familyControlsAuthorized: Bool = false
    @Published var notificationAuthorized: Bool = false
    @Published var allPermissionsGranted: Bool = false

    private var permissionCheckTask: Task<Void, Never>?
    private var lastCheckDate: Date = .distantPast
    private let minimumCheckInterval: TimeInterval = 0.4

    private init() {
    }

    /// 모든 권한 상태 확인
    func checkPermissions(force: Bool = false) {
        if !force,
           Date().timeIntervalSince(lastCheckDate) < minimumCheckInterval {
            return
        }
        lastCheckDate = Date()

        permissionCheckTask?.cancel()
        checkFamilyControlsAuthorization()

        permissionCheckTask = Task { [weak self] in
            guard let self else { return }
            await self.checkNotificationAuthorization()
        }
    }

    /// Family Controls 권한 상태 확인
    func checkFamilyControlsAuthorization() {
        let status = AuthorizationCenter.shared.authorizationStatus
        familyControlsAuthorized = (status == .approved)
        updateAllPermissionsStatus()
    }

    /// 노티피케이션 권한 상태 확인
    func checkNotificationAuthorization() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let authorized = (settings.authorizationStatus == .authorized)
        await MainActor.run {
            notificationAuthorized = authorized
            updateAllPermissionsStatus()

            // App Group에 권한 상태 저장 (Extension에서 확인용)
            AppGroupManager.shared.saveNotificationAuthorizationStatus(authorized)
        }
    }

    /// Family Controls 권한 요청
    func requestFamilyControlsAuthorization() async throws {
        // 현재 권한 상태 확인
        let currentStatus = AuthorizationCenter.shared.authorizationStatus
        if currentStatus == .approved {
            await MainActor.run {
                checkFamilyControlsAuthorization()
            }
            return
        }

        do {
            // 약간의 지연 후 요청 (시스템 준비 시간)
            try await Task.sleep(for: .milliseconds(100))

            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            await MainActor.run {
                checkFamilyControlsAuthorization()
            }
        } catch {
            // 에러 상세 정보 수집
            let nsError = error as NSError
            let errorDescription = error.localizedDescription
            let errorDomain = nsError.domain
            let errorCode = nsError.code

            // Family Controls Agent 연결 에러 처리
            if errorDescription.contains("FamilyControlsAgent") ||
               errorDescription.contains("helper application") ||
               errorDomain.contains("FamilyControls") {
                throw PermissionError.familyControlsAgentError(
                    "Domain: \(errorDomain), Code: \(errorCode), Description: \(errorDescription)"
                )
            }
            throw PermissionError.familyControlsRequestFailed(error)
        }
    }

    /// 노티피케이션 권한 요청
    func requestNotificationAuthorization() async throws {
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        )
        await MainActor.run {
            notificationAuthorized = granted
            updateAllPermissionsStatus()

            // App Group에 권한 상태 저장 (Extension에서 확인용)
            AppGroupManager.shared.saveNotificationAuthorizationStatus(granted)
        }
    }

    /// 모든 필수 권한 요청
    func requestAllPermissions() async throws {
        try await requestFamilyControlsAuthorization()
        try await requestNotificationAuthorization()
    }

    /// 모든 필수 권한이 승인되었는지 확인
    func verifyAllRequiredPermissions() -> Bool {
        return familyControlsAuthorized && notificationAuthorized
    }

    /// 모든 권한 상태 업데이트
    private func updateAllPermissionsStatus() {
        allPermissionsGranted = verifyAllRequiredPermissions()
    }

    /// 설정 앱으로 이동하는 URL
    var settingsURL: URL? {
        URL(string: UIApplication.openSettingsURLString)
    }

    deinit {
        permissionCheckTask?.cancel()
    }
}

enum PermissionError: LocalizedError {
    case familyControlsRequestFailed(Error)
    case familyControlsAgentError(String)
    case notificationRequestFailed

    var errorDescription: String? {
        switch self {
        case .familyControlsRequestFailed(let error):
            return "Family Controls 권한 요청 실패: \(error.localizedDescription)"
        case .familyControlsAgentError(let message):
            return """
            Family Controls Agent 연결 실패

            에러: \(message)

            해결 방법:
            1. Xcode에서 프로젝트 설정 > Signing & Capabilities 탭으로 이동
            2. "+ Capability" 버튼을 클릭하고 "Family Controls"를 추가
            3. 앱을 완전히 삭제하고 다시 설치
            4. 기기 재시작 후 다시 시도
            5. 설정 > Screen Time이 활성화되어 있는지 확인
            """
        case .notificationRequestFailed:
            return "노티피케이션 권한 요청 실패"
        }
    }
}
