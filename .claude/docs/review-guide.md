# go-wbft 코드 리뷰 상세 가이드

> 이 문서는 스킬 프롬프트에서 분리된 상세 참조 자료이다.
> 필요 시 `Read .claude/docs/review-guide.md`로 로드한다.

## go-wbft 고유 코드 맵

geth 원본에 없는 go-wbft 전용 코드.

### 핵심 패키지 (go-wbft 전용)

| 패키지 | 역할 | 주요 파일 |
|--------|------|-----------|
| `consensus/wbft/` | WBFT 합의 엔진 (QBFT 기반) | 7개 하위 패키지, 39개 파일 |
| `consensus/wbft/backend/` | 합의 엔진 ↔ 이더리움 연결 | backend.go, engine.go, handler.go, api.go |
| `consensus/wbft/core/` | 핵심 합의 알고리즘 상태머신 | core.go, preprepare.go, prepare.go, commit.go, roundchange.go 외 12개 |
| `consensus/wbft/engine/` | 블록 봉인/검증 엔진 | engine.go, apply_extra.go |
| `consensus/wbft/messages/` | 합의 메시지 타입 | message.go, preprepare.go, prepare.go, commit.go, roundchange.go 외 2개 |
| `consensus/wbft/validator/` | 밸리데이터 집합 관리 | validator.go, default.go |
| `consensus/wbft/common/` | 공용 상수/에러 | constants.go, errors.go |
| `consensus/wpoa/` | go-wemix PoA 합의 (Croissant 이전) | consensus.go, gov.go, wemix_info.go 외 3개 |
| `consensus/wemix/` | WEMIX 합의 공통 인터페이스 | consensus.go |
| `wemixgov/` | 거버넌스 API 인터페이스 | govapi.go |
| `wemixgov/bind/` | ABI 바인딩 (자동 생성) | gen_gov_abi.go, gen_staking_abi.go 외 6개 |
| `wemixgov/cli/` | 거버넌스 CLI | govcli.go |
| `wemixgov/governance-wbft/` | WBFT 거버넌스 Go 구현 | governance.go, contracts.go, staking.go, ncp.go, stateutil.go |
| `cmd/gwemix/` | WEMIX 메인 클라이언트 | main.go 외 9개 |
| `cmd/genesis_generator/` | 제네시스 블록 생성기 | 3개 파일 |
| `cmd/db_migrator/` | DB 마이그레이션 도구 | 1개 파일 |

### 기존 패키지 내 go-wbft 고유 파일

| 파일 | 역할 |
|------|------|
| `core/wemix_genesis.go` | WEMIX 제네시스 설정 (CroissantConfig → alloc 변환) |
| `core/types/istanbul.go` | WBFT 블록 헤더 타입 (WBFTExtra, EpochInfo, Staker, SealerSet) |
| `params/config_wbft.go` | WBFT 체인 설정 (CroissantConfig, WBFTConfig, GovContracts, Upgrade, Transition) |
| `eth/handler_istanbul.go` | WBFT P2P 메시지 핸들러 |
| `eth/quorum_protocol.go` | Quorum 프로토콜 통합 |
| `eth/api_wemix.go` | WEMIX 공개 RPC API (BriocheConfig, HalvingSchedule, GetBriocheBlockReward) |

### geth 기존 파일 내 go-wbft 수정 부분

다음 파일들은 geth 원본에 존재하지만 go-wbft에서 수정/확장된 파일이다:

| 파일 | 수정 내용 |
|------|-----------|
| `core/genesis.go` | Croissant 제네시스 초기화 연동 |
| `core/blockchain.go` | WBFT 합의 엔진 연동 |
| `core/state_transition.go` | Fee Delegation, 블랙리스트 검증 |
| `core/state/statedb.go` | 블랙리스트/인가 상태 확장 |
| `core/vm/evm.go` | 네이티브 컨트랙트, 보안 제약 |
| `core/vm/interpreter.go` | WEMIX 확장 |
| `eth/backend.go` | WBFT 합의 엔진 초기화 |
| `eth/handler.go` | Istanbul 프로토콜 등록 |
| `eth/gasprice/gasprice.go` | 가스 가격 로직 확장 |
| `params/config.go` | CroissantBlock, BriocheBlock, BriocheConfig, CroissantConfig 필드 |

## 질문 유형별 탐색 가이드

### 유형 1: 특정 함수/타입 질문

1. `Grep`으로 함수/타입 정의 위치를 찾는다
2. `Read`로 해당 함수/타입의 코드를 읽는다
3. 함수 시그니처, GoDoc 주석, 핵심 로직을 분석하여 답한다

### 유형 2: 호출 관계 / 흐름 질문

1. `Grep`으로 함수명이 호출되는 위치를 검색한다
2. 호출자 함수의 코드를 `Read`로 확인한다
3. 필요 시 호출자의 호출자도 추적한다 (최대 3홉)
4. 흐름을 순서대로 정리하여 답한다

### 유형 3: 영향도 / 삭제 안전성 질문

1. `Grep`으로 해당 심볼의 모든 참조를 찾는다
2. 참조가 있는 패키지 목록을 정리한다
3. 각 참조의 맥락(호출, 타입 사용, import)을 분류한다
4. 영향 범위와 위험도를 판정하여 답한다

### 유형 4: 합의(WBFT) 관련 질문

WBFT 합의 흐름:
```
Core.Start() → handleEvents() 루프
  │
  ├─ 새 블록 요청 수신 → handleRequest()
  │   └─ sendPreprepareMsg() → 밸리데이터에게 PrePrepare 전파
  │
  ├─ PrePrepare 수신 → handlePreprepareMsg()
  │   └─ broadcastPrepare() → Prepare 메시지 전파
  │
  ├─ Prepare 수신 → handlePrepareMsg()
  │   └─ 쿼럼 도달 시 → broadcastCommit() → Commit 메시지 전파
  │
  ├─ Commit 수신 → handleCommitMsg()
  │   └─ 쿼럼 도달 시 → commitWBFT() → 블록 확정
  │
  ├─ 타임아웃 → handleTimeoutMsg()
  │   └─ handleRoundChangeMsg() → 새 라운드 시작
  │
  └─ 블록 확정 → handleFinalCommittedMsg()
      └─ startNewRound() → 다음 시퀀스
```

주요 파일:
- `consensus/wbft/core/handler.go` — 이벤트 루프, 메시지 라우팅
- `consensus/wbft/core/preprepare.go` — PrePrepare 단계
- `consensus/wbft/core/prepare.go` — Prepare 단계
- `consensus/wbft/core/commit.go` — Commit 단계
- `consensus/wbft/core/roundchange.go` — 라운드 체인지
- `consensus/wbft/core/core.go` — Core 구조체, 라운드 관리
- `consensus/wbft/backend/backend.go` — 합의 엔진 ↔ 이더리움 연결
- `consensus/wbft/engine/engine.go` — 블록 검증/봉인 엔진

### 유형 5: 거버넌스 (wemixgov) 질문

```
wemixgov/ 패키지 구조:
  ├─ govapi.go                  — GovContractApi, GovBackend 인터페이스
  ├─ bind/                      — ABI 바인딩 (자동 생성, 수정 금지)
  ├─ cli/govcli.go              — CLI 인터페이스
  └─ governance-wbft/           — WBFT 거버넌스 구현
      ├─ contracts.go           — 컨트랙트 바이트코드 (go:embed), 버전 매핑
      ├─ governance.go          — 컨트랙트 버전 검증, StateTransition 생성
      ├─ staking.go             — 스테이킹 상태 읽기/쓰기
      ├─ ncp.go                 — NCP 리스트 관리
      └─ stateutil.go           — 상태 유틸리티 (슬롯 계산)
```

거버넌스 컨트랙트 주소:
- GovConfig: `0x1000`, GovStaking: `0x1001`, GovRewardeeImp: `0x1002`, GovNCP: `0x1003`

### 유형 6: 트랜잭션 / EVM 질문

- 수수료 위임: `core/types/transaction_signing.go` → `core/state_transition.go`
- EVM 실행: `core/vm/evm.go` → `core/vm/interpreter.go` → `core/vm/instructions.go`
- 트랜잭션 처리: `core/state_processor.go` → `core/state_transition.go`

### 유형 7: 네트워크 / P2P 질문

- 합의 메시지 전달: `eth/handler_istanbul.go` → `consensus/wbft/backend/handler.go`
- 이더리움 프로토콜: `eth/handler.go` → `eth/protocols/eth/handler.go`
- 피어 관리: `p2p/server.go` → `p2p/peer.go`
- 노드 발견: `p2p/discover/`

### 유형 8: 제네시스 / 체인 설정 질문

- 제네시스: `core/wemix_genesis.go` → `core/genesis.go`
- 체인 설정: `params/config.go` + `params/config_wbft.go`
- 제네시스 생성기: `cmd/genesis_generator/`

### 유형 9: 패키지 구조 / 아키텍처 질문

1. `.claude/docs/build-source-files.md`의 패키지 목록과 카테고리별 집계를 읽는다
2. 해당 패키지의 주요 파일을 `Read`로 확인한다
3. 패키지 간 관계는 `Grep`으로 import 관계를 추적한다

### 유형 10: 코드 수정 / 기능 추가 요청

1. 유사한 기존 구현을 먼저 찾는다 (패턴 참고)
2. 수정 대상 파일과 영향 범위를 파악한다
3. 코드 수정 전에 변경 계획을 사용자에게 제시한다
4. 수정 후 `go build ./cmd/gwemix`로 빌드 확인을 안내한다

## 응답 형식

```
## 분석 결과

### 대상
- 파일: `consensus/wbft/core/commit.go:90`
- 함수: `handleCommitMsg(commit *wbfmessage.Commit) error`

### 동작
[함수의 핵심 동작을 단계별로 설명]

### 호출 관계
[호출자 → 대상 → 피호출자 흐름]

### 영향 범위 (해당 시)
[변경/삭제 시 영향받는 코드 목록]

### 관련 코드
[참고해야 할 다른 파일/함수 목록]
```
