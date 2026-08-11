//
//  UsageSession.swift
//  KeepYouOnTrack
//
//  Created by Kacey Kim on 1/26/26.
//

import Foundation

/// 앱 사용 세션 정보
struct UsageSession: Codable {
    let id: String
    let purpose: String
    let durationMinutes: Int
    let startDate: Date
    let endDate: Date?

    init(purpose: String, durationMinutes: Int) {
        self.id = UUID().uuidString
        self.purpose = purpose
        self.durationMinutes = durationMinutes
        self.startDate = Date()
        self.endDate = nil
    }

    var isActive: Bool {
        endDate == nil
    }

    var remainingMinutes: Int {
        guard endDate != nil else {
            let elapsed = Date().timeIntervalSince(startDate)
            let remaining = TimeInterval(durationMinutes * 60) - elapsed
            return max(0, Int(remaining / 60))
        }
        return 0
    }
}
