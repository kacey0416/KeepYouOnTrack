//
//  LiveActivityService.swift
//  KeepYouOnTrack
//
//  Created by Codex on 2/18/26.
//

import Foundation
import ActivityKit

@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()
    private var autoEndTask: Task<Void, Never>?

    private init() {}

    func startSessionActivity(session: UsageSession) {
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ LiveActivityService: Live Activities are disabled")
            return
        }

        let endDate = session.startDate.addingTimeInterval(TimeInterval(session.durationMinutes * 60))
        let attributes = SessionLiveActivityAttributes(
            purpose: session.purpose,
            sessionId: session.id
        )
        let content = ActivityContent(
            state: SessionLiveActivityAttributes.ContentState(endDate: endDate),
            staleDate: endDate
        )

        Task {
            let activities = Activity<SessionLiveActivityAttributes>.activities
            let sameSessionActivities = activities.filter { $0.attributes.sessionId == session.id }

            if let activity = sameSessionActivities.first {
                for duplicateActivity in sameSessionActivities.dropFirst() {
                    await duplicateActivity.end(nil, dismissalPolicy: .immediate)
                }
                if activity.content.state.endDate != endDate {
                    await activity.update(content)
                }
                scheduleAutoEnd(for: activity, at: endDate)
                return
            }

            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }

            do {
                let activity = try Activity<SessionLiveActivityAttributes>.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
                scheduleAutoEnd(for: activity, at: endDate)
            } catch {
                print("❌ LiveActivityService: Failed to start activity: \(error)")
            }
        }
    }

    func endAllActivities() async {
        guard #available(iOS 16.2, *) else { return }
        autoEndTask?.cancel()
        autoEndTask = nil
        for activity in Activity<SessionLiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    func endExpiredActivitiesIfNeeded(graceSeconds: TimeInterval = 2) async {
        guard #available(iOS 16.2, *) else { return }
        let cutoff = Date.now.addingTimeInterval(graceSeconds)
        for activity in Activity<SessionLiveActivityAttributes>.activities {
            if activity.content.state.endDate <= cutoff {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    @available(iOS 16.1, *)
    private func scheduleAutoEnd(
        for activity: Activity<SessionLiveActivityAttributes>,
        at endDate: Date
    ) {
        autoEndTask?.cancel()
        autoEndTask = Task { [weak self] in
            let remaining = endDate.timeIntervalSinceNow
            if remaining > 0 {
                try? await Task.sleep(for: .milliseconds(Int((remaining + 1) * 1000)))
            }
            guard !Task.isCancelled else { return }
            await activity.end(nil, dismissalPolicy: .immediate)
            self?.autoEndTask = nil
        }
    }
}
