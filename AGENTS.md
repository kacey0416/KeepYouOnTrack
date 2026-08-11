# AGENTS.md

## Repo Map
- `KeepYouOnTrack/`: main iOS app target
- `KeepYouOnTrack/Views`: SwiftUI screens and reusable UI
- `KeepYouOnTrack/ViewModels`: screen state and presentation logic
- `KeepYouOnTrack/Services`: FamilyControls, sessions, notifications, Live Activity orchestration
- `KeepYouOnTrack/Shared`: shared tokens and App Group helpers
- `KeepYouOnTrack/Models`: session and ActivityKit data models
- `SessionLiveActivityWidget/`: Live Activity + Dynamic Island UI
- `ShieldActionExtension/`: shield button actions
- `ShieldConfigurationExtension/`: shield appearance
- `DeviceActivityMonitorExtension/`: relock and session-ended callbacks

## Product Intent
- This app is an intent-based exception unlocker.
- Only one app may be unlocked at a time.
- Unlock always requires a free-text purpose plus a preset duration.
- When time expires, the app must relock immediately even if the user is still inside it.
- Live Activity and Dynamic Island are core UX, not optional polish.

## Active Flows
- Locked app tap -> shield UI -> notification -> main app manual input sheet
- Manual input submit -> save session -> temporarily unlock exactly one selected app
- Session expiry -> relock from foreground timer and background monitor fallback
- Opening a different locked app during a session -> terminate old session -> require a new purpose

## Source Of Truth
- `SessionManager` is the single source of truth for active session state.
- `AppGroupManager` handles persistence and cross-target sharing, not session business logic.
- Extensions should read shared state, not redefine session rules independently.

## Commands
- Build app:
  - ``/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project KeepYouOnTrack.xcodeproj -scheme KeepYouOnTrack -sdk iphonesimulator -derivedDataPath /private/tmp/KeepYouOnTrack-derived CODE_SIGNING_ALLOWED=NO build``
- Search code:
  - ``rg "SessionManager|FamilyControlsService|LiveActivityService" .``

## Commit Convention
- Use this format: `<emoji> <type>: <English summary>`
- Use only the following fixed prefixes:
  - `✨ feat`: user-facing features or UI behavior
  - `🛠️ fix`: bug fixes
  - `♻️ refactor`: code restructuring without behavior changes
  - `💊 test`: test additions or changes
  - `📁 docs`: documentation changes
  - `📦 chore`: project configuration, build settings, or maintenance
- Write the summary in English as a single concise sentence.
- Do not end the summary with a period.
- Keep each commit focused on one purpose.
- Omit the commit body by default. Add a short English body only when the reason, migration steps, compatibility impact, or an important constraint cannot fit clearly in the title.
- Example: `✨ feat: Add custom session duration input`

## Files To Read First
- `KeepYouOnTrack/Services/SessionManager.swift`
- `KeepYouOnTrack/Services/FamilyControlsService.swift`
- `KeepYouOnTrack/Shared/AppGroupManager.swift`
- `SessionLiveActivityWidget/SessionLiveActivityWidget.swift`
- `ShieldConfigurationExtension/ShieldConfigurationProvider.swift`
- `ShieldActionExtension/ShieldActionExtension.swift`
- `SHIELD_CONFIGURATION_EXPLANATION.md`
- `LIVE_ACTIVITY_RESEARCH.md`

## Rules
- Do not reintroduce category-based locking. App-only locking is the intended behavior.
- Do not allow multiple simultaneously unlocked apps.
- Do not add duration free-text input unless explicitly requested.
- Preserve App Group communication behavior across app and extensions.
- Keep SwiftUI views split into separate files when extracting meaningful UI parts.
- Prefer `AppDesignTokens` or asset-based colors over hardcoded UI colors.
- Treat `NotificationContentExtension/` as inactive unless the user explicitly asks to revive it.

## Ask Before Changing
- Session policy or relock behavior
- Duration presets
- Purpose input UX
- User-facing notification or shield copy
- Main session flow or entry flow

## Current Non-Goals
- Multiple simultaneously unlocked apps
- Category-based locking
- Session history or app-level statistics as the main focus of a task unless explicitly requested

## Verification
- Definition of done for this repo: a successful build is sufficient unless the user explicitly asks for more validation.
- After behavior changes, run the build command above.
- After session-flow changes, verify these cases manually if possible:
  - start session from shield flow
  - unlock exactly one app
  - open another locked app during an active session
  - expire session while app is foregrounded
  - Live Activity appears and updates
- After UI changes, check:
  - main app screen
  - manual session input sheet
  - Live Activity / Dynamic Island layouts

## Known Fragile Areas
- `SessionManager` foreground timer vs. background relock monitoring
- Darwin notification handoff between app and extensions
- App Group persistence timing
- Dynamic Island compact/minimal layouts
- Shield extension asset/color parity with the main app

## If Blocked
- Identify whether the problem is in:
  - main app state
  - shield extension handoff
  - App Group persistence
  - DeviceActivity timing
  - Live Activity rendering
- Then read the matching service/extension file before editing.
- If a change is UI-only, avoid touching session/relock logic.
