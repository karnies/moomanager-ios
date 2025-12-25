# MooManager iOS

무한매수법(Infinite Buying Strategy) 자동 계산 iOS 앱

## 기능

- **포트폴리오 관리**: 여러 종목의 무한매수법 설정 및 추적
- **실시간 시세**: Yahoo Finance API 연동으로 실시간 주가 조회
- **매매 이력**: 매수/매도 거래 기록 및 관리
- **자동 계산**: T값, 별%, 매수/매도가 자동 계산
- **RSI 지표**: RSI(14) 계산 및 매수 추천
- **정산 관리**: 종목별 매매 완료 시 정산 기록
- **백업/복원**: JSON 형식 데이터 백업 및 복원

## 지원 종목

TQQQ, SOXL, FNGU, TECL, UPRO, BULZ, LABU, TNA, FAS, CURE, NAIL

## 버전

- **v2.2**: 분할수 40, 매도목표 10% (기본)
- **v3.0**: 분할수 20, 매도목표 15%, 반복리 50% (기본)

## 기술 스택

- SwiftUI
- SwiftData
- Swift Concurrency (async/await, Actor)
- Yahoo Finance API

## 요구사항

- iOS 17.0+
- Xcode 15.0+

## 설치

```bash
git clone https://github.com/karnies/moomanager-ios.git
cd moomanager-ios
open MooManager.xcodeproj
```

## 라이선스

MIT License

## 작성자

[@karnies](https://github.com/karnies)
