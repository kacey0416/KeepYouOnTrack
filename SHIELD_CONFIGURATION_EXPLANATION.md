# Shield Configuration Extension 구현 원리 상세 설명

## 전체 플로우 다이어그램

```
[사용자 앱 선택]
    ↓
[FamilyControlsService.setShieldRestrictions()]
    ↓
[ManagedSettingsStore.shield.applications = Set<ApplicationToken>]
    ↓
[시스템(ManagedSettingsAgent)이 Shield 표시 필요 감지]
    ↓
[시스템이 Shield Configuration Extension 찾기]
    ↓
[ShieldConfigurationProvider.configuration() 호출] ← 여기서 푸시 발송 예정
    ↓
[ShieldConfiguration 반환 → 커스텀 Shield UI 표시]
    ↓
[사용자가 Shield 버튼 클릭]
    ↓
[ShieldConfigurationProvider.handle() 호출]
```

---

## 1. 메인 앱: Shield 설정 단계

### 파일: `KeepYouOnTrack/Services/FamilyControlsService.swift`

```swift
// Line 22: ManagedSettingsStore 인스턴스 생성
private let store = ManagedSettingsStore()

// Line 34-43: Shield 제한 설정
func setShieldRestrictions(selection: FamilyActivitySelection) {
    // ApplicationToken들을 Set으로 변환
    let applications = Set(selection.applicationTokens)

    // ⭐ 핵심: ManagedSettingsStore의 shield.applications에 설정
    // 이 설정이 시스템에 Shield 표시를 요청하는 트리거
    store.shield.applications = applications.isEmpty ? nil : applications
}
```

**작동 원리:**
- `ManagedSettingsStore`는 시스템 레벨의 설정 저장소
- `store.shield.applications`에 `Set<ApplicationToken>`을 설정하면
- 시스템(ManagedSettingsAgent)이 해당 앱들에 Shield를 표시하도록 예약
- **이 시점에는 아직 Shield가 표시되지 않음** (사용자가 앱을 실행할 때 표시됨)

---

## 2. 사용자가 잠금된 앱 실행 시

### 시스템 레벨 동작 (우리가 제어할 수 없음)

1. **사용자가 잠금된 앱 실행 시도**
   - 예: Instagram 앱 아이콘 탭

2. **SpringBoard(홈 화면 관리자)가 앱 실행 차단**
   - `store.shield.applications`에 해당 앱이 포함되어 있음을 확인
   - 앱 실행 대신 Shield 화면 표시 결정

3. **ManagedSettingsAgent 프로세스 활성화**
   - 시스템 프로세스: `com.apple.ManagedSettingsAgent`
   - Shield UI를 렌더링하고 표시하는 역할

4. **Shield Configuration Extension 찾기**
   ```
   ManagedSettingsAgent가 다음을 수행:
   - Extension Point: "com.apple.ManagedSettingsUI.shield-configuration" 검색
   - 해당 Extension Point를 가진 앱의 Extension 찾기
   - Extension의 PrincipalClass 로드
   ```

---

## 3. Shield Configuration Extension 호출 (예상 동작)

### 파일: `ShieldConfigurationExtension/Info.plist`

```xml
<key>NSExtension</key>
<dict>
    <!-- Extension Point Identifier: 시스템이 이 Extension을 찾는 키 -->
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.ManagedSettingsUI.shield-configuration</string>

    <!-- PrincipalClass: Extension이 로드될 때 인스턴스화할 클래스 -->
    <key>NSExtensionPrincipalClass</key>
    <string>ShieldConfigurationProvider</string>
</dict>
```

**작동 원리:**
- 시스템이 `com.apple.ManagedSettingsUI.shield-configuration` Extension Point를 찾음
- 해당 Extension을 가진 앱의 Bundle ID 확인
- `ShieldConfigurationProvider` 클래스를 로드하고 인스턴스 생성
- `init()` 메서드 호출 (우리가 추가한 로깅이 여기서 실행되어야 함)

---

## 4. ShieldConfigurationProvider 클래스

### 파일: `ShieldConfigurationExtension/ShieldConfigurationProvider.swift`

### 4.1 클래스 선언 및 프로토콜

```swift
// Line 15: ShieldConfigurationDelegate 프로토콜 구현
class ShieldConfigurationProvider: ShieldConfigurationDelegate {
```

**ShieldConfigurationDelegate 프로토콜:**
- `ManagedSettingsUI` 프레임워크에서 제공
- 두 가지 필수 메서드:
  1. `configuration(for:) -> ShieldConfiguration` - Shield UI 설정
  2. `handle(action:for:completionHandler:)` - 버튼 액션 처리

### 4.2 초기화 (Extension 로드 시)

```swift
// Line 20-23: Extension이 시스템에 로드될 때 호출
init() {
    logger.info("🛡️ ShieldConfigurationProvider: INIT CALLED - Extension loaded!")
    print("🛡️ ShieldConfigurationProvider: INIT CALLED - Extension loaded!")
}
```

**예상 호출 시점:**
- Extension이 처음 로드될 때 (앱 설치 후 첫 Shield 표시)
- 또는 시스템이 Extension을 메모리에 유지하는 동안

**현재 문제:** 이 로그가 전혀 출력되지 않음 → Extension이 로드되지 않음

### 4.3 configuration 메서드 (Shield UI 설정)

```swift
// Line 26-43: Shield가 표시될 때마다 호출되어야 함
func configuration(for context: ShieldConfigurationContext) -> ShieldConfiguration {
    // context: Shield를 표시하는 컨텍스트 정보
    // - context.activityName: DeviceActivityName (예: "blockedApps")
    // - context.application: ApplicationToken (잠금된 앱)

    logger.info("🛡️ ShieldConfigurationProvider: configuration called...")

    // ⭐ 핵심: Shield 표시 시점에 푸시 알림 발송
    sendNotification()

    // ShieldConfiguration 반환: 커스텀 Shield UI 설정
    return ShieldConfiguration(
        backgroundBlurStyle: .regular,  // 배경 블러 스타일
        icon: nil,                      // 아이콘 (nil = 기본)
        title: ShieldConfiguration.Label(text: "앱이 잠금되었습니다", color: .white),
        subtitle: ShieldConfiguration.Label(text: "목적을 입력하고 시간을 설정하세요", color: .white),
        primaryButtonLabel: ShieldConfiguration.Label(text: "목적 입력", color: .white),
        primaryButtonBackgroundColor: .systemBlue,
        secondaryButtonLabel: ShieldConfiguration.Label(text: "취소", color: .white)
    )
}
```

**예상 호출 시점:**
- 사용자가 잠금된 앱 실행 시도
- 시스템이 Shield를 표시하기 직전
- **이 메서드가 호출되어야 푸시 알림이 발송됨**

**현재 문제:** 이 메서드가 호출되지 않음

### 4.4 handle 메서드 (버튼 액션 처리)

```swift
// Line 46-60: Shield의 버튼이 클릭되었을 때 호출
func handle(action: ShieldAction, for context: ShieldConfigurationContext,
           completionHandler: @escaping (ShieldActionResponse) -> Void) {

    switch action {
    case .primaryButtonPressed:  // "목적 입력" 버튼
        sendNotification()  // 추가로 푸시 발송
        completionHandler(.close)  // Shield 닫기
    case .secondaryButtonPressed:  // "취소" 버튼
        completionHandler(.close)  // Shield 닫기
    }
}
```

**예상 호출 시점:**
- 사용자가 Shield의 "목적 입력" 또는 "취소" 버튼 클릭
- `completionHandler`를 호출하여 Shield 닫기 여부 결정

### 4.5 sendNotification 메서드 (푸시 알림 발송)

```swift
// Line 63-86: 로컬 푸시 알림 발송
private func sendNotification() {
    let content = UNMutableNotificationContent()
    content.title = "목적을 입력하세요"
    content.body = "이 앱을 사용하는 목적과 시간을 설정해주세요"
    content.sound = .default
    content.categoryIdentifier = "PURPOSE_INPUT"  // Notification Content Extension과 연결

    // 즉시 발송 (trigger: nil = 즉시)
    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil
    )

    UNUserNotificationCenter.current().add(request) { error in
        // 에러 처리 또는 성공 로깅
    }
}
```

**작동 원리:**
- `UNUserNotificationCenter`를 사용하여 로컬 푸시 알림 발송
- `categoryIdentifier: "PURPOSE_INPUT"`로 설정하여
- `NotificationContentExtension`이 이 알림을 확장하여 목적/시간 입력 UI 표시

---

## 5. Entitlements 설정

### 파일: `ShieldConfigurationExtension/ShieldConfigurationExtension.entitlements`

```xml
<key>com.apple.developer.family-controls</key>
<true/>

<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.kacey.keepyouontrack</string>
</array>
```

**작동 원리:**
- `family-controls`: Family Controls 기능 사용 권한
- `application-groups`: 메인 앱과 Extension 간 데이터 공유

---

## 6. 전체 예상 플로우 (정상 작동 시)

```
1. [메인 앱] FamilyControlsService.setShieldRestrictions()
   → store.shield.applications = [Instagram, TikTok, ...]

2. [사용자] Instagram 앱 실행 시도

3. [시스템] SpringBoard가 Shield 표시 필요 감지
   → ManagedSettingsAgent 활성화

4. [시스템] Extension Point 검색
   → "com.apple.ManagedSettingsUI.shield-configuration" 찾기
   → Bundle ID: com.kacey.keepyouontrack.ShieldConfigurationExtension

5. [시스템] ShieldConfigurationProvider 인스턴스 생성
   → init() 호출 ✅ (로그: "INIT CALLED")

6. [시스템] configuration(for:) 호출
   → ShieldConfigurationProvider.configuration() 실행 ✅
   → sendNotification() 호출 ✅
   → 푸시 알림 발송 ✅
   → ShieldConfiguration 반환

7. [시스템] Shield UI 표시
   → 사용자에게 커스텀 Shield 화면 표시

8. [사용자] "목적 입력" 버튼 클릭

9. [시스템] handle(action:for:completionHandler:) 호출
   → ShieldConfigurationProvider.handle() 실행 ✅
   → completionHandler(.close) → Shield 닫기
```

---

## 7. 현재 문제 분석

### 문제 1: Extension이 로드되지 않음

**증상:**
- `init()` 로그가 전혀 출력되지 않음
- `configuration()` 메서드가 호출되지 않음

**가능한 원인:**

1. **Extension Point Identifier 불일치**
   - Info.plist: `com.apple.ManagedSettingsUI.shield-configuration`
   - 시스템이 찾는 것: `com.apple.ManagedSettingsUI.shield-configuration-service`
   - 로그에서 "Beginning discovery for flags: 1024, point: com.apple.ManagedSettingsUI.shield-configuration-service" 확인

2. **Bundle Identifier 문제**
   - Extension의 Bundle ID가 시스템에 등록되지 않음
   - "No bundle identifier for effective allowed client" 에러

3. **Code Signing 문제**
   - Extension의 코드 서명이 메인 앱과 일치하지 않음
   - Team ID 불일치

4. **Extension이 실제로 빌드되지 않음**
   - Xcode에서 Extension 타겟이 제대로 빌드되지 않음
   - Embed Foundation Extensions 설정 누락

### 문제 2: ManagedSettingsAgent가 Extension을 찾지 못함

**로그 분석:**
```
Getting client values for shield.applications
No bundle identifier for effective allowed client: Application.none
Beginning discovery for flags: 1024, point: com.apple.ManagedSettingsUI.shield-configuration-service
```

**의미:**
- ManagedSettingsAgent가 Shield Configuration Extension을 찾고 있음
- 하지만 "effective allowed client"를 찾지 못함
- Extension이 시스템에 등록되지 않았거나, Bundle ID가 인식되지 않음

---

## 8. 설계 의도 vs 실제 동작

### 설계 의도:
1. Shield가 표시될 때 `configuration()` 메서드가 자동 호출
2. 이 시점에 푸시 알림 발송
3. 사용자가 Shield 버튼 클릭 시 `handle()` 메서드 호출

### 실제 동작:
1. Shield는 정상적으로 표시됨 (시스템 기본 Shield)
2. 하지만 Extension이 호출되지 않음
3. 따라서 커스텀 Shield UI도 표시되지 않고, 푸시 알림도 발송되지 않음

---

## 9. 핵심 문제점

**Shield Configuration Extension이 작동하려면:**
1. Extension이 시스템에 올바르게 등록되어야 함
2. Extension Point Identifier가 정확해야 함
3. Bundle Identifier가 올바르게 설정되어야 함
4. Code Signing이 올바르게 설정되어야 함

**현재 상태:**
- 위 조건들이 모두 충족되지 않은 것으로 보임
- Extension이 시스템에 등록되지 않아 호출되지 않음

---

## 10. 대안 접근 방법

Extension이 작동하지 않으므로, 다음 대안을 고려:

### 대안 1: 메인 앱에서 직접 푸시 발송
- `setShieldRestrictions()` 호출 시점에 푸시 발송
- Extension 의존성 제거
- 더 간단하고 확실한 방법

### 대안 2: DeviceActivityMonitor Extension 재시도
- `intervalDidStart()` 메서드가 호출되도록 수정
- 다른 메서드 시도 (`eventDidReachThreshold` 등)

### 대안 3: App Groups + 폴링
- Extension에서 UserDefaults에 플래그 기록
- 메인 앱에서 주기적으로 확인하여 푸시 발송
