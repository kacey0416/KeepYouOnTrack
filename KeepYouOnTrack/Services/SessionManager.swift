//
//  SessionManager.swift
//  KeepYouOnTrack
//
//  Created by Kacey Kim on 1/26/26.
//

import Foundation
import Combine
import CoreFoundation
import UIKit
import DeviceActivity
import FamilyControls

/// 세션 관리 서비스
/// 활성 세션 모니터링 및 잠금 해제/재설정 관리
@MainActor
class SessionManager: ObservableObject {
    static let shared = SessionManager()

    @Published var activeSession: UsageSession?
    @Published var isSessionActive: Bool = false
    @Published var showManualInputScreen: Bool = false

    nonisolated(unsafe) private var timer: Timer?
    private let appGroupManager = AppGroupManager.shared
    private let familyControlsService = FamilyControlsService.shared
    private let unlockActivityNamePrefix = "temporaryUnlockSession."
    private let relockWarningLeadTime: TimeInterval = 15 * 60
    private var appStateObservers: [NSObjectProtocol] = []
    private let defaultsPropagationRetryCount = 3
    private let defaultsPropagationDelayNanoseconds: UInt64 = 120_000_000
    private var unlockPhase: UnlockPhase = .idle

    private enum UnlockPhase: Equatable {
        case idle
        case handling(sessionId: String)
        case handled(sessionId: String)
    }

    private init() {
        loadActiveSession(forceRefresh: true)
        setupUnlockObserver()
        setupSessionEndedObserver()
        setupManualInputObserver()
        setupAppStateObservers()
        consumeManualInputRequestIfNeeded()
        restoreSessionStateOnLaunch()
    }

    /// 활성 세션 로드
    func loadActiveSession(forceRefresh: Bool = false) {
        activeSession = appGroupManager.loadActiveSession(useCache: !forceRefresh)
        isSessionActive = (activeSession != nil)
    }

    private func restoreSessionStateOnLaunch() {
        guard let session = activeSession else {
            familyControlsService.ensureRelockIfNeeded()
            Task {
                await LiveActivityService.shared.endAllActivities()
                await LiveActivityService.shared.endExpiredActivitiesIfNeeded()
            }
            return
        }

        let endTime = sessionEndDate(for: session)
        if Date() >= endTime {
            // 앱이 재실행될 때 이미 만료된 세션은 즉시 정리하여 상태 불일치를 막는다.
            endSession()
            return
        }

        startSessionTimer(session: session)
        if UIApplication.shared.applicationState == .active {
            LiveActivityService.shared.startSessionActivity(session: session)
        }
    }

    private func setupAppStateObservers() {
        let center = NotificationCenter.default

        let willEnterForeground = center.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reconcileSessionState(forceRefreshFromAppGroup: true)
            }
        }

        let didBecomeActive = center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reconcileSessionState()
            }
        }

        appStateObservers = [willEnterForeground, didBecomeActive]
    }

    private func reconcileSessionState(forceRefreshFromAppGroup: Bool = false) {
        if forceRefreshFromAppGroup {
            loadActiveSession(forceRefresh: true)
        } else if activeSession == nil {
            loadActiveSession()
        } else {
            isSessionActive = true
        }
        guard let session = activeSession else {
            familyControlsService.ensureRelockIfNeeded()
            Task {
                await LiveActivityService.shared.endExpiredActivitiesIfNeeded()
            }
            return
        }

        let endTime = sessionEndDate(for: session)
        if Date() >= endTime {
            endSession()
            return
        }

        // 앱이 백그라운드에 있던 동안 타이머가 멈출 수 있어 복귀 시 재시작
        if timer == nil {
            startSessionTimer(session: session)
        }

        if UIApplication.shared.applicationState == .active {
            LiveActivityService.shared.startSessionActivity(session: session)
        }
    }

    func consumeManualInputRequestIfNeeded() {
        if appGroupManager.checkAndClearManualInputScreenRequest() {
            showManualInputScreen = true
        }
    }

    func dismissManualInput() {
        _ = appGroupManager.checkAndClearManualInputScreenRequest()
        showManualInputScreen = false
    }

    func startSessionFromManualInput(purpose: String, minutes: Int) {
        let session = UsageSession(purpose: purpose, durationMinutes: minutes)
        appGroupManager.saveActiveSession(session)
        activeSession = session
        isSessionActive = true
        unlockPhase = .idle

        applyPendingUnlockTarget()
        startSessionTimer(session: session)
        if UIApplication.shared.applicationState == .active {
            LiveActivityService.shared.startSessionActivity(session: session)
        }
        scheduleRelockMonitoring(for: session)
        dismissManualInput()
    }

    /// 세션 타이머 시작
    private func startSessionTimer(session: UsageSession) {
        stopTimer()

        let endTime = sessionEndDate(for: session)

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkSessionExpiration(endTime: endTime, session: session)
            }
        }
        timer?.tolerance = 0.3
    }

    /// 세션 만료 확인
    private func checkSessionExpiration(endTime: Date, session: UsageSession) {
        if Date() >= endTime {
            // 시간 만료 - 잠금 재설정
            endSession()
        }
    }

    /// 세션 종료
    func endSession() {
        let endingSessionId = activeSession?.id
        stopTimer()

        // 잠금 재설정
        familyControlsService.relock()

        // 세션 삭제
        appGroupManager.clearActiveSession()
        activeSession = nil
        isSessionActive = false
        unlockPhase = .idle

        // 공유 세션을 먼저 지운 뒤 monitor를 중지해야 종료 callback이 같은 세션을 중복 처리하지 않는다.
        stopRelockMonitoring(for: endingSessionId)
        Task { await LiveActivityService.shared.endAllActivities() }
    }

    /// 타이머 중지
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// 잠금 해제 요청 옵저버 설정 (이벤트 기반)
    private func setupUnlockObserver() {
        let notificationName = "com.kacey.keepyouontrack.unlockRequest" as CFString
        let center = CFNotificationCenterGetDarwinNotifyCenter()

        let observer: @convention(c) (CFNotificationCenter?, UnsafeMutableRawPointer?, CFNotificationName?, UnsafeRawPointer?, CFDictionary?) -> Void = { _, observer, _, _, _ in
            if let observer = observer {
                let manager = Unmanaged<SessionManager>.fromOpaque(observer).takeUnretainedValue()
                Task { @MainActor in
                    await manager.handleUnlockRequest()
                }
            }
        }

        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            observer,
            notificationName,
            nil,
            .deliverImmediately
        )

        print("✅ SessionManager: CFNotificationCenter unlock observer registered for: \(notificationName)")
    }

    /// 잠금 해제 요청 처리 (이벤트 기반)
    private func handleUnlockRequest() async {
        print("🔓 SessionManager: handleUnlockRequest() called")

        // App Group 플래그는 cross-process 전파 타이밍으로 즉시 보이지 않을 수 있어 짧게 재시도
        guard await waitForUnlockRequestFlag() else {
            print("⚠️ SessionManager: No unlock request found in App Group")
            return
        }
        print("✅ SessionManager: Unlock request flag found and cleared")

        guard let session = await waitForActiveSession() else {
            print("⚠️ SessionManager: No active session found after retry, cannot unlock")
            return
        }
        print("📋 SessionManager: Active session loaded: \(session.purpose)")

        guard beginUnlockHandling(for: session.id) else {
            print("⏭️ SessionManager: Duplicate unlock event ignored for session \(session.id)")
            return
        }
        var didSucceed = false
        defer {
            finishUnlockHandling(for: session.id, didSucceed: didSucceed)
        }

        guard let pendingSelection = await waitForPendingUnlockSelection() else {
            print("⚠️ SessionManager: No pending unlock selection found after retry")
            familyControlsService.relock()
            return
        }

        // 잠금 해제
        print("🔓 SessionManager: Applying pending unlock target")
        familyControlsService.unlock(temporarilyAllowing: pendingSelection)
        appGroupManager.clearPendingUnlockSelection()
        print("✅ SessionManager: Shield unlocked")

        // 세션 시작 (타이머 시작)
        print("⏱️ SessionManager: Starting session timer for \(session.durationMinutes) minutes")
        startSessionTimer(session: session)
        scheduleRelockMonitoring(for: session)
        if UIApplication.shared.applicationState == .active {
            LiveActivityService.shared.startSessionActivity(session: session)
        }
        didSucceed = true
        print("✅ SessionManager: Session timer started")
    }

    /// 세션 종료 이벤트 옵저버 설정 (DeviceActivityMonitorExtension -> Main App)
    private func setupSessionEndedObserver() {
        let notificationName = "com.kacey.keepyouontrack.sessionEnded" as CFString
        let center = CFNotificationCenterGetDarwinNotifyCenter()

        let observer: @convention(c) (CFNotificationCenter?, UnsafeMutableRawPointer?, CFNotificationName?, UnsafeRawPointer?, CFDictionary?) -> Void = { _, observer, _, _, _ in
            if let observer = observer {
                let manager = Unmanaged<SessionManager>.fromOpaque(observer).takeUnretainedValue()
                Task { @MainActor in
                    manager.handleSessionEndedFromExtension()
                }
            }
        }

        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            observer,
            notificationName,
            nil,
            .deliverImmediately
        )
    }

    private func handleSessionEndedFromExtension() {
        stopTimer()
        stopRelockMonitoring()
        Task {
            await LiveActivityService.shared.endAllActivities()
            await LiveActivityService.shared.endExpiredActivitiesIfNeeded()
        }
        loadActiveSession(forceRefresh: true)
        if activeSession == nil {
            isSessionActive = false
            unlockPhase = .idle
        }
    }

    private func setupManualInputObserver() {
        let notificationName = "com.kacey.keepyouontrack.openManualInput" as CFString
        let center = CFNotificationCenterGetDarwinNotifyCenter()

        let observer: @convention(c) (CFNotificationCenter?, UnsafeMutableRawPointer?, CFNotificationName?, UnsafeRawPointer?, CFDictionary?) -> Void = { _, observer, _, _, _ in
            if let observer = observer {
                let manager = Unmanaged<SessionManager>.fromOpaque(observer).takeUnretainedValue()
                Task { @MainActor in
                    manager.consumeManualInputRequestIfNeeded()
                }
            }
        }

        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            observer,
            notificationName,
            nil,
            .deliverImmediately
        )
    }

    private func scheduleRelockMonitoring(for session: UsageSession) {
        let endDate = sessionEndDate(for: session)
        guard endDate > Date.now else {
            print("⚠️ SessionManager: Session already expired before relock monitoring could start")
            endSession()
            return
        }

        let center = DeviceActivityCenter()
        let activityName = unlockActivityName(for: session.id)
        let staleActivityNames = center.activities.filter {
            $0.rawValue.hasPrefix(unlockActivityNamePrefix) && $0 != activityName
        }
        if !staleActivityNames.isEmpty {
            center.stopMonitoring(staleActivityNames)
        }

        let calendar = Calendar.current
        let monitoringEndDate = endDate.addingTimeInterval(relockWarningLeadTime)
        let startComponents = scheduleComponents(for: session.startDate, calendar: calendar)
        let endComponents = scheduleComponents(for: monitoringEndDate, calendar: calendar)
        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false,
            // DeviceActivity는 15분 미만 구간을 허용하지 않는다. 긴 구간을 예약하고
            // 실제 세션 종료 시각에는 intervalWillEndWarning callback으로 재잠금한다.
            warningTime: DateComponents(minute: Int(relockWarningLeadTime / 60))
        )

        do {
            try center.startMonitoring(activityName, during: schedule)
            let remainingSeconds = Int(endDate.timeIntervalSinceNow.rounded(.down))
            print("✅ SessionManager: Relock monitoring scheduled to end in \(remainingSeconds)s")
        } catch {
            print("❌ SessionManager: Failed to start relock monitoring: \(error)")
        }
    }

    private func stopRelockMonitoring(for sessionId: String? = nil) {
        let center = DeviceActivityCenter()
        let activityNames = center.activities.filter { activityName in
            guard activityName.rawValue.hasPrefix(unlockActivityNamePrefix) else {
                return false
            }
            guard let sessionId else { return true }
            return activityName == unlockActivityName(for: sessionId)
        }
        guard !activityNames.isEmpty else { return }
        center.stopMonitoring(activityNames)
    }

    private func unlockActivityName(for sessionId: String) -> DeviceActivityName {
        DeviceActivityName("\(unlockActivityNamePrefix)\(sessionId)")
    }

    private func scheduleComponents(for date: Date, calendar: Calendar) -> DateComponents {
        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        return components
    }

    private func applyPendingUnlockTarget() {
        if let pendingSelection = appGroupManager.loadPendingUnlockSelection() {
            familyControlsService.unlock(temporarilyAllowing: pendingSelection)
            appGroupManager.clearPendingUnlockSelection()
        } else {
            // 요청 대상이 없으면 현재 잠금 상태를 유지한다.
            print("⚠️ SessionManager: Pending unlock target not found, keeping current shield state")
        }
    }

    private func waitForUnlockRequestFlag() async -> Bool {
        for attempt in 0..<defaultsPropagationRetryCount {
            if appGroupManager.checkAndClearUnlockRequest() {
                return true
            }
            if attempt < defaultsPropagationRetryCount - 1 {
                try? await Task.sleep(for: .nanoseconds(defaultsPropagationDelayNanoseconds))
            }
        }
        return false
    }

    private func waitForActiveSession() async -> UsageSession? {
        for attempt in 0..<defaultsPropagationRetryCount {
            loadActiveSession(forceRefresh: true)
            if let session = activeSession {
                return session
            }
            if attempt < defaultsPropagationRetryCount - 1 {
                try? await Task.sleep(for: .nanoseconds(defaultsPropagationDelayNanoseconds))
            }
        }
        return nil
    }

    private func sessionEndDate(for session: UsageSession) -> Date {
        session.startDate.addingTimeInterval(TimeInterval(session.durationMinutes * 60))
    }

    private func waitForPendingUnlockSelection() async -> FamilyActivitySelection? {
        for attempt in 0..<defaultsPropagationRetryCount {
            if let selection = appGroupManager.loadPendingUnlockSelection() {
                return selection
            }
            if attempt < defaultsPropagationRetryCount - 1 {
                try? await Task.sleep(for: .nanoseconds(defaultsPropagationDelayNanoseconds))
            }
        }
        return nil
    }

    private func beginUnlockHandling(for sessionId: String) -> Bool {
        switch unlockPhase {
        case .handling(let handlingSessionId) where handlingSessionId == sessionId:
            return false
        case .handled(let handledSessionId) where handledSessionId == sessionId:
            return false
        default:
            unlockPhase = .handling(sessionId: sessionId)
            return true
        }
    }

    private func finishUnlockHandling(for sessionId: String, didSucceed: Bool) {
        guard case .handling(let handlingSessionId) = unlockPhase,
              handlingSessionId == sessionId else {
            return
        }
        unlockPhase = didSucceed ? .handled(sessionId: sessionId) : .idle
    }
    deinit {
        // deinit은 actor context 밖에서 실행되므로 nonisolated 필요
        timer?.invalidate()
        timer = nil
        for observer in appStateObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        appStateObservers.removeAll()
    }
}
