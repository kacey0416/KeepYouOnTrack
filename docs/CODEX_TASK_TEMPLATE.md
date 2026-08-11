# Codex Task Template

Use this format when assigning work to Codex in this repo.

```text
Goal:
- What should change?

Acceptance criteria:
- Observable behavior 1
- Observable behavior 2
- Observable behavior 3

Constraints:
- Do not change unrelated UI
- Keep app-only locking behavior
- Preserve single-unlock-session rule

Files or areas to inspect first:
- KeepYouOnTrack/Services/SessionManager.swift
- KeepYouOnTrack/Views/...

Verify:
- /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project KeepYouOnTrack.xcodeproj -scheme KeepYouOnTrack -sdk iphonesimulator -derivedDataPath /private/tmp/KeepYouOnTrack-derived CODE_SIGNING_ALLOWED=NO build

Output:
- Summarize changed files
- List risks or follow-up checks
```

## Example

```text
Goal:
- Improve Dynamic Island readability for active unlock sessions

Acceptance criteria:
- Remaining timer is visible in compact presentation
- Purpose text is visible in expanded presentation
- No layout warnings from negative frame sizes

Constraints:
- Do not change session duration behavior
- Do not change shield unlock flow

Files or areas to inspect first:
- SessionLiveActivityWidget/SessionLiveActivityWidget.swift
- KeepYouOnTrack/Services/LiveActivityService.swift
- KeepYouOnTrack/Models/SessionLiveActivityAttributes.swift

Verify:
- /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project KeepYouOnTrack.xcodeproj -scheme KeepYouOnTrack -sdk iphonesimulator -derivedDataPath /private/tmp/KeepYouOnTrack-derived CODE_SIGNING_ALLOWED=NO build

Output:
- Summarize changed files
- Note any UI states that still need device validation
```
