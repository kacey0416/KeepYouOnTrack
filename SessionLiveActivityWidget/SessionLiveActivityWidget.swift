import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.1, *)
struct SessionLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionLiveActivityAttributes.self) { context in
            // Lock Screen / StandBy
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye.fill")
                            .font(.caption)
                        Text("Focus Session")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(AppDesignTokens.accentRed)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(AppDesignTokens.accentRed.opacity(0.16))
                    )

                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                            .foregroundStyle(.white.opacity(0.8))
                        timerText(for: context.state.endDate, font: .title3.weight(.semibold))
                    }
                }

                Text(context.attributes.purpose)
                    .font(.headline.weight(.semibold))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Text("Ends")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))

                    Text(context.state.endDate, style: .time)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)

                    Spacer()

                    Text("잠금 해제 진행 중")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(16)
            .activityBackgroundTint(AppDesignTokens.backgroundBlack.opacity(0.92))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: "eye.fill")
                            .foregroundStyle(AppDesignTokens.accentRed)
                        Text("FOCUS")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("남은 시간")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.75))
                        timerText(for: context.state.endDate, font: .headline.weight(.bold))
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.purpose)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(AppDesignTokens.accentRed.opacity(0.16))
                        )
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.attributes.purpose)
                            .lineLimit(2)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 8) {
                            Circle()
                                .fill(AppDesignTokens.accentRed)
                                .frame(width: 6, height: 6)
                            Text("잠금 해제 상태")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.75))
                            Spacer()
                            Text(context.state.endDate, style: .time)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "eye.fill")
                    .foregroundStyle(AppDesignTokens.accentRed)
            } compactTrailing: {
                timerText(for: context.state.endDate, font: .caption2.weight(.semibold))
            } minimal: {
                compactTimerText(for: context.state.endDate)
                    .foregroundStyle(AppDesignTokens.accentRed)
            }
            .keylineTint(AppDesignTokens.accentRed)
        }
    }

    @ViewBuilder
    private func compactTimerText(for endDate: Date) -> some View {
        if endDate > Date.now {
            Text(
                timerInterval: Date.now...endDate,
                pauseTime: nil,
                countsDown: true,
                showsHours: false
            )
            .font(.caption2.weight(.bold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.55)
        } else {
            Text("00:00")
                .font(.caption2.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
    }

    @ViewBuilder
    private func timerText(for endDate: Date, font: Font = .subheadline) -> some View {
        if endDate > Date() {
            Text(timerInterval: Date()...endDate, countsDown: true)
                .font(font)
                .monospacedDigit()
        } else {
            Text("00:00")
                .font(font)
                .monospacedDigit()
        }
    }
}
