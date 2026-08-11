//
//  PermissionRequestView.swift
//  KeepYouOnTrack
//
//  Created by Kacey Kim on 1/26/26.
//

import SwiftUI
import FamilyControls

struct PermissionRequestView: View {
    @StateObject private var permissionManager = PermissionManager.shared
    @State private var isRequesting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // 앱 아이콘 및 제목
            VStack(spacing: 16) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 60))
                    .foregroundStyle(.tint)

                Text("필수 권한이 필요합니다")
                    .font(.title)
                    .fontWeight(.bold)

                Text("이 앱을 사용하려면 다음 권한이 필요합니다")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            // 권한 설명 카드들
            VStack(spacing: 16) {
                PermissionCard(
                    icon: "lock.shield",
                    title: "Family Controls",
                    description: "특정 앱 사용을 제한하고 목적 기반 사용을 관리하기 위해 필요합니다.",
                    isAuthorized: permissionManager.familyControlsAuthorized
                )

                PermissionCard(
                    icon: "bell.badge",
                    title: "알림",
                    description: "앱 사용 목적을 입력하고 시간 제한을 설정하기 위해 필요합니다.",
                    isAuthorized: permissionManager.notificationAuthorized
                )
            }
            .padding(.horizontal)

            // 에러 메시지
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Spacer()

            // 권한 요청 버튼
            VStack(spacing: 12) {
                Button(action: requestPermissions) {
                    HStack {
                        if isRequesting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("권한 허용하기")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(permissionManager.allPermissionsGranted ? Color.gray : Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
                .disabled(isRequesting || permissionManager.allPermissionsGranted)

                // 설정 앱으로 이동 버튼 (권한이 거부된 경우)
                if !permissionManager.allPermissionsGranted && !isRequesting {
                    if let settingsURL = permissionManager.settingsURL {
                        Link("설정에서 권한 변경하기", destination: settingsURL)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .onChange(of: permissionManager.allPermissionsGranted) {
            if permissionManager.allPermissionsGranted {
                errorMessage = nil
            }
        }
    }

    private func requestPermissions() {
        isRequesting = true
        errorMessage = nil

        Task {
            do {
                // Family Controls 권한을 먼저 개별적으로 요청
                try await permissionManager.requestFamilyControlsAuthorization()

                // 노티피케이션 권한 요청
                try await permissionManager.requestNotificationAuthorization()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isRequesting = false

                    // 에러 로깅 (디버깅용)
                    print("Permission Error: \(error)")
                    if let nsError = error as NSError? {
                        print("Error Domain: \(nsError.domain)")
                        print("Error Code: \(nsError.code)")
                        print("Error UserInfo: \(nsError.userInfo)")
                    }
                }
                return
            }

            await MainActor.run {
                isRequesting = false
            }
        }
    }
}

struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let isAuthorized: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(isAuthorized ? .green : .accentColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)

                    if isAuthorized {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline)
                    }
                }

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    PermissionRequestView()
}
