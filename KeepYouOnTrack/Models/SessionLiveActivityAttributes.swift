//
//  SessionLiveActivityAttributes.swift
//  KeepYouOnTrack
//
//  Created by Codex on 2/18/26.
//

import Foundation
import ActivityKit

@available(iOS 16.1, *)
struct SessionLiveActivityAttributes: ActivityAttributes {
    let purpose: String

    struct ContentState: Codable, Hashable {
        var endDate: Date
    }

    var sessionId: String
}
