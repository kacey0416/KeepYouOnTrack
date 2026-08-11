//
//  FamilyControlsService.swift
//  KeepYouOnTrack
//
//  Created by Kacey Kim on 1/26/26.
//

import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings

/// Family Controls 서비스
/// 앱 선택, 잠금 설정, 모니터링 관리를 담당합니다.
@MainActor
class FamilyControlsService: ObservableObject {
    static let shared = FamilyControlsService()

    @Published var isMonitoring = false

    private let center = DeviceActivityCenter()
    private let store = ManagedSettingsStore()
    private let activityName = DeviceActivityName("blockedApps")
    private let appGroupIdentifier = "group.com.kacey.keepyouontrack"
    private let lockedSelectionKey = "lockedSelection"

    // 현재 잠금된 앱 선택 저장 (재잠금용)
    private var currentSelection: FamilyActivitySelection?

    private init() {
        currentSelection = loadPersistedSelection()
        // 이전 버전에서 남은 카테고리 쉴드는 항상 정리한다.
        store.shield.applicationCategories = nil
        // 기존 모니터링 상태 확인
        checkMonitoringStatus()
    }

    /// 선택된 앱으로 잠금 설정
    func setShieldRestrictions(selection: FamilyActivitySelection) {
        let appOnlySelection = sanitizeToApplicationsOnly(selection)
        let applications = Set(appOnlySelection.applicationTokens)

        // 카테고리 잠금은 비활성화: 앱 잠금만 반영
        store.shield.applications = applications.isEmpty ? nil : applications
        store.shield.applicationCategories = nil
    }

    /// 잠금 해제
    func removeShieldRestrictions() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        isMonitoring = false
    }

    /// 잠금 해제 (모니터링은 유지)
    func unlock() {
        // Shield만 해제하고 모니터링은 계속
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }

    /// 특정 앱/카테고리만 일시 허용하고 나머지는 계속 잠금
    func unlock(temporarilyAllowing selectionToAllow: FamilyActivitySelection) {
        if currentSelection == nil {
            currentSelection = loadPersistedSelection()
        }

        guard let lockedSelection = currentSelection else {
            // 잠금 기준이 없으면 기존 동작으로 fallback
            unlock()
            return
        }

        let sanitizedLockedSelection = sanitizeToApplicationsOnly(lockedSelection)
        let sanitizedAllowedSelection = sanitizeToApplicationsOnly(selectionToAllow)

        let lockedApps = Set(sanitizedLockedSelection.applicationTokens)
        let allowedApps = Set(sanitizedAllowedSelection.applicationTokens)

        let remainingApps = lockedApps.subtracting(allowedApps)

        store.shield.applications = remainingApps.isEmpty ? nil : remainingApps
        store.shield.applicationCategories = nil
    }

    /// 잠금 재설정
    func relock(selection: FamilyActivitySelection) {
        let sanitizedSelection = sanitizeToApplicationsOnly(selection)
        persistSelection(sanitizedSelection)
        setShieldRestrictions(selection: sanitizedSelection)
    }

    /// 모니터링 시작
    func startMonitoring(selection: FamilyActivitySelection) {
        // Shield 설정
        setShieldRestrictions(selection: selection)

        // DeviceActivityCenter에 모니터링 등록
        // 24시간 전체를 커버하는 스케줄 (항상 활성)
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        print("🔔 FamilyControlsService: Starting monitoring for activity: \(activityName)")
        print("🔔 FamilyControlsService: Schedule: 00:00 - 23:59 (repeats: true)")

        do {
            try center.startMonitoring(activityName, during: schedule)
            isMonitoring = true
            print("✅ FamilyControlsService: Monitoring started successfully")
        } catch {
            print("❌ FamilyControlsService: Failed to start monitoring: \(error)")
            isMonitoring = false
        }
    }

    /// 모니터링 중지
    func stopMonitoring() {
        center.stopMonitoring([activityName])
        clearPersistedSelection()
        removeShieldRestrictions()
        isMonitoring = false
    }

    /// 모니터링 상태 확인
    func checkMonitoringStatus() {
        // DeviceActivityCenter의 현재 모니터링 상태 확인
        // 실제로는 모니터링 중인지 확인하는 직접적인 방법이 없으므로
        // Shield 설정 상태로 판단
        isMonitoring = (store.shield.applications != nil && !store.shield.applications!.isEmpty)
    }

    /// 선택된 앱으로 즉시 잠금 처리
    func applyLock(selection: FamilyActivitySelection) {
        let sanitizedSelection = sanitizeToApplicationsOnly(selection)
        currentSelection = sanitizedSelection
        persistSelection(sanitizedSelection)
        startMonitoring(selection: sanitizedSelection)
    }

    /// 잠금 재설정 (이전 선택으로)
    func relock() {
        // relock 기준은 persisted selection을 우선 사용한다.
        // 메모리 currentSelection이 오래된 상태여도 종료 시점에 잠금 복구가 보장되어야 한다.
        let persistedSelection = loadPersistedSelection()
        let resolvedSelection = persistedSelection ?? currentSelection
        guard let selection = resolvedSelection else {
            print("⚠️ FamilyControlsService: No selection available for relock")
            return
        }

        let sanitizedSelection = sanitizeToApplicationsOnly(selection)
        currentSelection = sanitizedSelection
        relock(selection: sanitizedSelection)
    }

    /// 세션 정보가 없을 때도 persisted selection 기준으로 잠금 상태를 복구한다.
    func ensureRelockIfNeeded() {
        guard let persistedSelection = loadPersistedSelection() else { return }
        let sanitizedSelection = sanitizeToApplicationsOnly(persistedSelection)
        guard !sanitizedSelection.applicationTokens.isEmpty else { return }

        let expectedApplications = Set(sanitizedSelection.applicationTokens)
        let currentApplications = store.shield.applications ?? Set<ApplicationToken>()
        guard currentApplications != expectedApplications else { return }

        currentSelection = sanitizedSelection
        setShieldRestrictions(selection: sanitizedSelection)
    }

    private func persistSelection(_ selection: FamilyActivitySelection) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = try? PropertyListEncoder().encode(sanitizeToApplicationsOnly(selection)) else { return }
        defaults.set(data, forKey: lockedSelectionKey)
    }

    private func loadPersistedSelection() -> FamilyActivitySelection? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: lockedSelectionKey),
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return nil
        }
        let sanitizedSelection = sanitizeToApplicationsOnly(selection)
        if !selection.categoryTokens.isEmpty,
           let sanitizedData = try? PropertyListEncoder().encode(sanitizedSelection) {
            defaults.set(sanitizedData, forKey: lockedSelectionKey)
        }
        return sanitizedSelection
    }

    private func clearPersistedSelection() {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        defaults.removeObject(forKey: lockedSelectionKey)
    }

    private func sanitizeToApplicationsOnly(_ selection: FamilyActivitySelection) -> FamilyActivitySelection {
        var sanitizedSelection = FamilyActivitySelection()
        sanitizedSelection.applicationTokens = selection.applicationTokens
        return sanitizedSelection
    }
}
