//
//  AppGroupManager.swift
//  KeepYouOnTrack
//
//  Created by Kacey Kim on 1/26/26.
//

import Foundation
import FamilyControls

/// App Group을 통한 데이터 공유 관리
class AppGroupManager {
    static let shared = AppGroupManager()

    private let appGroupIdentifier = "group.com.kacey.keepyouontrack"
    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private init() {}
    private let activeSessionKey = "activeSession"
    private let activeSessionIdentifierKey = "activeSessionIdentifier"
    private let pendingUnlockSelectionKey = "pendingUnlockSelection"
    private var cachedActiveSession: UsageSession?
    private var hasCachedActiveSession = false

    // MARK: - 세션 관리

    /// 현재 활성 세션 저장
    func saveActiveSession(_ session: UsageSession) {
        guard let userDefaults = userDefaults else { return }

        if let data = try? JSONEncoder().encode(session) {
            userDefaults.set(data, forKey: activeSessionKey)
            userDefaults.set(session.id, forKey: activeSessionIdentifierKey)
            cachedActiveSession = session
            hasCachedActiveSession = true
        }
    }

    /// 현재 활성 세션 로드
    func loadActiveSession(useCache: Bool = true) -> UsageSession? {
        if useCache, hasCachedActiveSession {
            return cachedActiveSession
        }

        guard let userDefaults = userDefaults,
              let data = userDefaults.data(forKey: activeSessionKey),
              let session = try? JSONDecoder().decode(UsageSession.self, from: data) else {
            cachedActiveSession = nil
            hasCachedActiveSession = true
            return nil
        }
        userDefaults.set(session.id, forKey: activeSessionIdentifierKey)
        cachedActiveSession = session
        hasCachedActiveSession = true
        return session
    }

    /// 활성 세션 삭제
    func clearActiveSession() {
        userDefaults?.removeObject(forKey: activeSessionKey)
        userDefaults?.removeObject(forKey: activeSessionIdentifierKey)
        cachedActiveSession = nil
        hasCachedActiveSession = true
    }

    // MARK: - 잠금 해제 요청

    /// 잠금 해제 요청 플래그 설정
    func requestUnlock() {
        userDefaults?.set(true, forKey: "unlockRequested")
        userDefaults?.set(Date(), forKey: "unlockRequestTimestamp")
    }

    /// 잠금 해제 요청 확인 및 초기화
    func checkAndClearUnlockRequest() -> Bool {
        guard let userDefaults = userDefaults,
              userDefaults.bool(forKey: "unlockRequested") else {
            return false
        }
        userDefaults.removeObject(forKey: "unlockRequested")
        userDefaults.removeObject(forKey: "unlockRequestTimestamp")
        return true
    }

    // MARK: - 알림 권한 상태

    /// 노티피케이션 권한 상태 저장 (Extension에서 확인용)
    func saveNotificationAuthorizationStatus(_ authorized: Bool) {
        userDefaults?.set(authorized, forKey: "notificationAuthorized")
    }

    /// 노티피케이션 권한 상태 확인
    func isNotificationAuthorized() -> Bool {
        return userDefaults?.bool(forKey: "notificationAuthorized") ?? false
    }

    // MARK: - 수동 입력 화면 요청

    /// 쉴드 버튼으로 앱 입력 화면 열기 요청 플래그 설정
    func requestManualInputScreen() {
        userDefaults?.set(true, forKey: "manualInputRequested")
        userDefaults?.set(Date(), forKey: "manualInputRequestTimestamp")
    }

    /// 앱 입력 화면 요청 확인 및 초기화
    func checkAndClearManualInputScreenRequest() -> Bool {
        guard let userDefaults = userDefaults,
              userDefaults.bool(forKey: "manualInputRequested") else {
            return false
        }
        userDefaults.removeObject(forKey: "manualInputRequested")
        userDefaults.removeObject(forKey: "manualInputRequestTimestamp")
        return true
    }

    // MARK: - 잠금 해제 대상(요청 앱/카테고리)

    func savePendingUnlockSelection(_ selection: FamilyActivitySelection) {
        guard let userDefaults = userDefaults,
              let data = try? PropertyListEncoder().encode(sanitizeToApplicationsOnly(selection)) else { return }
        userDefaults.set(data, forKey: pendingUnlockSelectionKey)
    }

    func loadPendingUnlockSelection() -> FamilyActivitySelection? {
        guard let userDefaults = userDefaults,
              let data = userDefaults.data(forKey: pendingUnlockSelectionKey),
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return nil
        }
        return sanitizeToApplicationsOnly(selection)
    }

    func clearPendingUnlockSelection() {
        userDefaults?.removeObject(forKey: pendingUnlockSelectionKey)
    }

    private func sanitizeToApplicationsOnly(_ selection: FamilyActivitySelection) -> FamilyActivitySelection {
        var sanitizedSelection = FamilyActivitySelection()
        sanitizedSelection.applicationTokens = selection.applicationTokens
        return sanitizedSelection
    }
}
