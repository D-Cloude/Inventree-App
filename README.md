# InvenTree Mobile App

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Android](https://github.com/inventree/inventree-app/actions/workflows/android.yaml/badge.svg)
![iOS](https://github.com/inventree/inventree-app/actions/workflows/ios.yaml/badge.svg)

InvenTree 재고 관리 시스템의 모바일 / 태블릿 동반 앱입니다.  
[Flutter](https://flutter.dev/) 환경으로 작성되어 Android 및 iOS 기기를 기본 지원합니다.

---

## 주요 기능

### 재고 조사 (Stocktake / 재물조사)

위치별 재물조사를 지원하는 바코드 기반 검증 모드입니다.

**확인 모드 (Verification Mode)**
- 위치를 선택하면 해당 위치의 모든 재고 항목이 자동으로 로드됩니다.
- 바코드를 스캔하면 목록의 항목이 **확인완료**로 표시됩니다.
- 목록에 없는 항목을 스캔하면 오류 메시지가 표시됩니다 ("이 위치에 없는 항목").
- AppBar에 `스캔완료 / 전체` 진행 현황이 실시간으로 표시됩니다.

**자유 스캔 모드 (Free-form Mode)**
- 위치 지정 없이 아무 재고 항목이나 스캔하여 목록에 추가할 수 있습니다.

**결과 제출 및 내보내기**
- 수량 수정 후 **재물조사 제출** 버튼으로 서버(`stock/count/`)에 일괄 제출합니다.
- 제출 완료 시 UTF-8 BOM CSV 파일이 자동 생성되어 열립니다 (한글 Excel 호환).
- CSV 컬럼: 부품명, 배치코드, 위치, 확인수량, 확인여부

### 바코드 스캔

- 카메라 기반 QR코드 / 바코드 스캔 (`mobile_scanner`)
- 배치 코드(Batch Code) 스캔 지원
- 성공/실패 사운드 피드백
- 줌 슬라이더, 토치, 전·후면 카메라 전환
- 단일 스캔 / 연속 스캔 모드 선택 가능

### 재고 관리

- 재고 항목 조회, 생성, 수정
- 위치 이동 (Transfer), 위치 계층 스캔
- 구매 주문 (Purchase Order) 입고 처리
- 라벨 프린터 연동

### 다국어 지원 (i18n / L10n)

40개 이상의 언어를 지원합니다:

| 언어 | 코드 |
|------|------|
| 한국어 | ko |
| 영어 | en |
| 일본어 | ja |
| 중국어 (간체/번체) | zh_CN / zh_TW |
| 독일어 | de |
| 프랑스어 | fr |
| 스페인어 | es |
| 러시아어 | ru |
| ... (총 40+) | |

재물조사 관련 문자열은 모든 언어에서 현지화됩니다.

---

## 설치

### Google Play Store (Android)

[Google Play Store](https://play.google.com/store/apps/details?id=inventree.inventree_app)에서 설치

### Apple App Store (iOS)

[Apple App Store](https://apps.apple.com/au/app/inventree/id1581731101)에서 설치

---

## 개발 환경 설정

### 요구 사항

- Flutter SDK `^3.8.1`
- Dart SDK (Flutter 포함)
- Android Studio / VS Code

### 빌드

```bash
# 의존성 설치
flutter pub get

# 디버그 빌드 실행
flutter run

# 릴리즈 APK 빌드
flutter build apk --release

# iOS 빌드
flutter build ios --release
```

자세한 빌드 방법은 [BUILDING.md](BUILDING.md)를 참고하세요.

---

## 프로젝트 구조

```
lib/
├── barcode/          # 바코드 스캔 모듈
│   ├── barcode.dart       # 메인 바코드 핸들러 & 라우팅
│   ├── camera_controller.dart  # 카메라 UI
│   ├── handler.dart       # 추상 핸들러 베이스
│   ├── stock.dart         # 재고 바코드 핸들러 (재물조사 포함)
│   └── tones.dart         # 스캔 사운드 피드백
├── inventree/        # API 모델 (재고, 부품, 주문 등)
├── widget/           # UI 위젯
│   └── stock/
│       ├── stocktake.dart      # 재물조사 화면
│       └── location_display.dart  # 위치 상세 화면
└── l10n/             # 다국어 리소스
    ├── app_en.arb         # 영어 (소스)
    ├── ko_KR/             # 한국어
    └── collected/         # 생성된 Dart 클래스
```

---

## 라이선스

MIT License — 자세한 내용은 [LICENSE](LICENSE) 파일을 참고하세요.

---

## 기여

기여 방법은 [CONTRIBUTING.md](CONTRIBUTING.md)를 참고하세요.
