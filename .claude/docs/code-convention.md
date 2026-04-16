# go-wbft 코드 컨벤션 (§1-§4)

> Go 및 Solidity 네이밍, 포맷팅, 커밋 메시지 규칙.

---

## 1. Go 코드 컨벤션

### 파일 네이밍

- **snake_case**: `wemix_genesis.go`, `config_wbft.go`
- 테스트 파일: `*_test.go`
- 도메인 분할: `{domain}_{function}.go` (예: `handler_istanbul.go`)
- 자동 생성: `gen_*.go`, `gen_*_rlp.go`, `*.pb.go` — 수정 금지

### 패키지 네이밍

- 소문자, 단일 단어 선호
- 충돌 시 별칭 사용: `wbftcommon "consensus/wbft/common"`

### 변수/상수 네이밍

| 유형 | 패턴 | 예시 |
|------|------|------|
| 내보내기 변수 | PascalCase | `DefaultConfig` |
| 비내보내기 변수 | camelCase | `blockPeriod` |
| 설정 상수 | UPPER_SNAKE_CASE | `GOV_CONTRACT_VERSION_1` |
| 타입 상수 | PascalCase | `RoundRobin`, `Sticky` |
| 에러 변수 | Err 접두사 | `ErrStoppedEngine`, `ErrUnknownBlock` |

### 함수 네이밍

| 유형 | 패턴 | 예시 |
|------|------|------|
| 내보내기 | PascalCase | `ExtractWBFTExtra()` |
| 비내보내기 | camelCase | `handleCommitMsg()` |
| 생성자 | `New*()` | `NewRoundRobinProposerPolicy()` |
| 인터페이스 검증 | `var _ Interface = &Type{}` | |

### Import 정렬

3개 그룹, 빈 줄로 구분:

```go
import (
    // 1. 표준 라이브러리
    "fmt"
    "math/big"

    // 2. 내부 패키지
    "github.com/ethereum/go-ethereum/common"
    "github.com/ethereum/go-ethereum/params"

    // 3. 외부 패키지
    "github.com/naoina/toml"
)
```

### 에러 처리

- sentinel 에러: `errors.New("message")`
- 에러 래핑: `fmt.Errorf("context: %w", err)`
- 즉시 반환: 에러 발생 시 조기 리턴

### 포맷팅

- `gofmt` / `goimports` 필수
- 탭 들여쓰기
- 줄 길이 120자 권장

---

## 2. Solidity 코드 컨벤션

### 파일 구조 순서

1. SPDX 라이선스 + Copyright
2. `pragma solidity ^0.8.x`
3. import (OpenZeppelin → 내부 → 라이브러리)
4. contract 본문 (using → types → state → constants → events → errors → modifiers → functions)

### 네이밍

| 유형 | 패턴 | 예시 |
|------|------|------|
| 컨트랙트 | PascalCase | `GovStaking`, `GovConfig` |
| 인터페이스 | I 접두사 | `IGovCouncil`, `IFeeRecipient` |
| 구현체 | Imp 접미사 | `GovRewardeeImp` |
| 공개 함수 | camelCase | `getMinimumStaking()` |
| 내부 함수 | _ 접두사 | `_initialize()` |
| 상수 | UPPER_SNAKE_CASE | `SLOT_GOV_CONFIG_MINIMUM_STAKING` |
| private 상태변수 | __ 접두사 | `__minimumStaking` |
| stack 변수 | _ 접두사 (섀도잉 방지) | `_amount` |

### Import

- named import만 사용 (와일드카드 금지)
- 예: `import {IGovCouncil} from "./IGovCouncil.sol";`

### NatSpec

- `@title`, `@notice`, `@dev`, `@param`, `@return` 사용
- `@custom:security-contact` 권장

---

## 3. 커밋 메시지

### Conventional Commits 형식

```
type: description #issue
```

| type | 용도 |
|------|------|
| feat | 새로운 기능 |
| fix | 버그 수정 |
| docs | 문서 변경 |
| refactor | 리팩토링 |
| test | 테스트 |
| chore | 기타 작업 |
| ci | CI/CD 변경 |

---

## 4. 파일 헤더

### Go 파일

```go
// Copyright 2024 The go-wemix-wbft Authors
// This file is part of the go-wemix-wbft library.
//
// The go-wemix-wbft library is free software: ...
// (GNU Lesser General Public License v3)
```

파생 파일은 원본 출처 명시:

```go
// This file is derived from quorum/consensus/istanbul/config.go (2024.07.25).
// Modified and improved for the wemix development.
```

### Solidity 파일

```solidity
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright 2025 The go-wemix-wbft Authors
```
