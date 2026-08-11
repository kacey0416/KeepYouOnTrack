//
//  LockedApp.swift
//  KeepYouOnTrack
//
//  Created by Kacey Kim on 1/26/26.
//

import Foundation
import FamilyControls

/// 잠금된 앱 정보
struct LockedApp: Identifiable, Codable {
    var id: String
    var token: String // ApplicationToken의 문자열 표현

    init(token: String) {
        self.id = UUID().uuidString
        self.token = token
    }
}

/// 잠금된 앱 그룹 관리
class LockedAppGroup: ObservableObject {
    @Published var selectedApps: FamilyActivitySelection = FamilyActivitySelection()

    private let appGroupIdentifier = "group.com.kacey.keepyouontrack"
    private let lockedSelectionKey = "lockedSelection"

    init() {
        if let loadedSelection = loadPersistedSelection() {
            selectedApps = loadedSelection
        }
    }

    /// 선택된 앱이 있는지 확인
    var hasSelection: Bool {
        !selectedApps.applicationTokens.isEmpty
    }

    private func loadPersistedSelection() -> FamilyActivitySelection? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: lockedSelectionKey),
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return nil
        }
        var sanitizedSelection = FamilyActivitySelection()
        sanitizedSelection.applicationTokens = selection.applicationTokens
        if !selection.categoryTokens.isEmpty,
           let sanitizedData = try? PropertyListEncoder().encode(sanitizedSelection) {
            defaults.set(sanitizedData, forKey: lockedSelectionKey)
        }
        return sanitizedSelection
    }
}
