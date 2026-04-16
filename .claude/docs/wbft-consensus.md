# WBFT 합의 엔진 (§14-§18)

> WBFT 내부 동작, 헤더 Extra 구조, RPC API, P2P 프로토콜, Epoch/Validator 관리.

---

## 14. WBFT 합의 엔진

### 상태 머신

WBFT 합의는 4가지 상태를 순환한다:

| 상태 | 설명 |
|------|------|
| PrePrepare | Proposer가 블록 제안 전파 |
| Prepare | 밸리데이터들이 제안 수락/검증 |
| Commit | 쿼럼 도달 시 커밋 서명 전파 |
| RoundChange | 타임아웃 또는 실패 시 새 라운드 |

### 메시지 코드

| 코드 | 이름 | 용도 |
|------|------|------|
| 0x12 | Preprepare | 블록 제안 |
| 0x13 | Prepare | 제안 수락 |
| 0x14 | Commit | 커밋 서명 |
| 0x15 | RoundChange | 라운드 전환 |

### 쿼럼 계산

```
쿼럼 = ceil((N - F) * 2 / 3)  단, F = floor((N - 1) / 3)
간단히: ceil(2N/3)
```

### 합의 흐름 (정상 경로)

```
1. Proposer가 sendPreprepareMsg() → PrePrepare 메시지 브로드캐스트
2. 밸리데이터가 handlePreprepareMsg() → 검증 후 broadcastPrepare()
3. Prepare 쿼럼 도달 → broadcastCommit()
4. Commit 쿼럼 도달 → commitWBFT() → 블록 확정
```

### 패키지별 역할

| 패키지/파일 | 역할 |
|------------|------|
| `consensus/wbft/core/core.go` | Core 구조체 — 합의 상태 관리, 라운드 시작/종료 |
| `consensus/wbft/core/handler.go` | 이벤트 루프, 메시지 디스패치 |
| `consensus/wbft/core/preprepare.go` | PrePrepare 메시지 처리 |
| `consensus/wbft/core/prepare.go` | Prepare 메시지 처리 |
| `consensus/wbft/core/commit.go` | Commit 메시지 처리, 블록 확정 |
| `consensus/wbft/core/roundchange.go` | RoundChange 처리, 새 라운드 시작 |
| `consensus/wbft/core/backlog.go` | 미래 메시지 저장 (나중에 재처리) |
| `consensus/wbft/core/roundstate.go` | 현재 라운드 상태 관리 |
| `consensus/wbft/core/extraseal.go` | Prepare/Commit 시일 처리 |
| `consensus/wbft/core/justification.go` | 정당성 증명 로직 |
| `consensus/wbft/core/priorstate.go` | 이전 라운드/밸리데이터 상태 추적 |
| `consensus/wbft/core/qbft_msg_set.go` | QBFT 메시지 집합 관리 |
| `consensus/wbft/core/request.go` | 블록 제안 요청 |
| `consensus/wbft/core/final_committed.go` | 최종 커밋 처리 |
| `consensus/wbft/backend/backend.go` | Backend — 합의 엔진 ↔ 이더리움 연결 |
| `consensus/wbft/backend/engine.go` | Engine 래퍼 — Author, VerifyHeader, Finalize, Seal |
| `consensus/wbft/backend/handler.go` | P2P 메시지 핸들링 |
| `consensus/wbft/backend/api.go` | RPC API 구현 |
| `consensus/wbft/engine/engine.go` | 상위 엔진 — 블록 검증/봉인 |
| `consensus/wbft/engine/apply_extra.go` | Extra 데이터 조작 |
| `consensus/wbft/messages/` | 각 메시지 타입 정의 및 인코딩/디코딩 |
| `consensus/wbft/validator/` | ValidatorSet 인터페이스 및 기본 구현 |
| `consensus/wbft/config.go` | Config 구조체, GetConfig(), GetGovContracts() |
| `consensus/wbft/types.go` | 핵심 타입 (Proposal, View, Validator, ValidatorSet) |

### WBFT Config 구조체

파일: `consensus/wbft/config.go`

```go
type Config struct {
    RequestTimeout              uint64                  // 각 라운드 타임아웃 (밀리초)
    BlockPeriod                 uint64                  // 블록 간 최소 시간 (초)
    ProposerPolicy              *ProposerPolicy         // RoundRobin 또는 Sticky
    Epoch                       uint64                  // 에폭 길이 (블록 수)
    AllowedFutureBlockTime      uint64                  // 미래 블록 허용 시간
    BlockReward                 *math.HexOrDecimal256   // 블록 리워드
    BlockRewardBeneficiary      *params.BeneficiaryInfo // 리워드 수혜자
    TargetValidators            uint64                  // 목표 밸리데이터 수
    MaxRequestTimeoutSeconds    uint64                  // 최대 라운드 타임아웃
    StabilizingStakersThreshold uint64                  // 안정화 스테이커 임계값
    UseNCP                      bool                    // NCP 사용 여부
    Transitions                 []params.Transition     // 파라미터 전환 이력
    GovContractUpgrades         []params.Upgrade        // 거버넌스 컨트랙트 업그레이드 이력
}
```

**주의사항:**
- `RequestTimeout`은 밀리초 단위이지만 ChainConfig의 `RequestTimeoutSeconds`는 초 단위
- `GetConfig(blockNumber)` — 블록 번호에 따라 Transitions를 적용한 Config 반환
- `GetGovContracts(blockNumber, chainConfig)` — 블록 번호에 따라 거버넌스 컨트랙트 반환

---

## 15. WBFT 블록 헤더 Extra

파일: `core/types/istanbul.go`

### WBFTExtra 구조체

```go
type WBFTExtra struct {
    VanityData        []byte                // 32바이트 바닐라 데이터 (노드 정보 인코딩)
    RandaoReveal      []byte                // BLS 서명 (블록 번호에 대한 랜덤 기여)
    PrevRound         uint32                // 이전 블록의 라운드 번호
    PrevPreparedSeal  *WBFTAggregatedSeal   // 이전 블록의 Prepare 시일
    PrevCommittedSeal *WBFTAggregatedSeal   // 이전 블록의 Commit 시일
    Round             uint32                // 현재 라운드 번호
    PreparedSeal      *WBFTAggregatedSeal   // 현재 블록의 Prepare 시일
    CommittedSeal     *WBFTAggregatedSeal   // 현재 블록의 Commit 시일
    EpochInfo         *EpochInfo            // 에폭 마지막 블록에만 존재
}
```

### WBFTAggregatedSeal

```go
type WBFTAggregatedSeal struct {
    Sealers   SealerSet  // 서명자 비트맵
    Signature []byte     // BLS 집합 서명 (96바이트)
}
```

### SealerSet (비트맵)

- 바이트 배열로 표현된 비트맵. 각 비트가 밸리데이터 인덱스를 나타냄
- `SetSealer(index)`, `IsSealer(index)`, `GetSealers()` → 서명자 인덱스 목록 반환

### EpochInfo (에폭 마지막 블록에만 존재)

```go
type EpochInfo struct {
    Stakers       []*Staker  // 다음 에폭 스테이커 목록 (인덱스 변경 가능)
    Validators    []uint32   // 다음 에폭 밸리데이터 (스테이커 인덱스 사용)
    BLSPublicKeys [][]byte   // 다음 에폭 BLS 공개키
    Stabilizing   bool       // 안정화 에폭 여부 (스테이커 < threshold)
}

type Staker struct {
    Addr      common.Address
    Diligence uint64          // 단위: 10^-6
}
```

### 주요 함수

- `ExtractWBFTExtra(header)` — 블록 헤더에서 WBFTExtra 추출
- `WBFTFilteredHeader(header)` — 시일 제거된 헤더 (해시 계산용)
- `WBFTFilteredHeaderWithRound(header, round)` — 특정 라운드의 필터된 헤더

### Diligence 상수

```go
DiligenceDenominator = 1_000_000
DefaultDiligence     = 2 * DiligenceDenominator * 95 / 100  // 1,900,000 (최대의 95%)
```

**주의사항:**
- `IstanbulExtraVanity`는 32바이트 고정
- BLS 서명은 96바이트
- `EpochInfo`는 에폭의 마지막 블록에만 존재
- `Validators`는 주소가 아닌 스테이커 인덱스 배열

---

## 16. WBFT 커스텀 RPC

파일: `consensus/wbft/backend/api.go`

### istanbul 네임스페이스 API

| 메서드 | 설명 |
|--------|------|
| `istanbul_nodeAddress` | 현재 노드의 서명 주소 |
| `istanbul_getCommitSignersFromBlock(number)` | 특정 블록의 커밋 서명자 목록 |
| `istanbul_getCommitSignersFromBlockByHash(hash)` | 해시로 커밋 서명자 조회 |
| `istanbul_getValidators(number)` | 특정 블록의 밸리데이터 목록 |
| `istanbul_getValidatorsAtHash(hash)` | 해시로 밸리데이터 조회 |
| `istanbul_status(startBlock, endBlock)` | 밸리데이터 활동 통계 |
| `istanbul_isValidator(number)` | 현재 노드가 밸리데이터인지 확인 |
| `istanbul_getWbftExtraInfo(number)` | 블록의 WBFTExtra 정보 (JSON 형태) |

### Status 응답 구조

```go
type Status struct {
    SealerActivity SealerActivity         // 시일 서명 통계 (prepared, committed, prevPrepared, prevCommitted, total)
    AuthorCounts   map[common.Address]int // 블록 제안 횟수
    BlockRange     BlockRange             // 조회 블록 범위
    RoundStats     RoundStats             // 라운드 분포 통계
}
```

### WEMIX RPC (eth 네임스페이스 확장)

파일: `eth/api_wemix.go`

| 메서드 | 설명 |
|--------|------|
| `wemix_briocheConfig` | Brioche halving 설정 |
| `wemix_halvingSchedule` | halving 스케줄 목록 |
| `wemix_getBriocheBlockReward(number)` | 특정 블록의 리워드 금액 |

---

## 17. Istanbul P2P

### 프로토콜 정보

| 항목 | 값 |
|------|-----|
| 프로토콜 이름 | `istanbul` |
| 프로토콜 버전 | `100` |
| 메시지 타입 | 22개 |

### 아키텍처

```
eth 프로토콜 + istanbul/100 서브프로토콜 (eth 피어 위에서 동작)
```

### 핵심 파일

| 파일 | 역할 |
|------|------|
| `eth/handler_istanbul.go` | Istanbul 메시지 핸들러 등록 및 처리 |
| `consensus/wbft/backend/handler.go` | 합의 메시지 처리 |
| `eth/protocols/eth/peer.go` | 피어 관리 |
| `eth/protocols/eth/qlight_deps.go` | QLight 의존성 |

**주의사항:**
- Istanbul 프로토콜은 eth 피어에 의존 — eth 피어 없이 동작 불가
- `ErrStoppedEngine`은 동기화 중 정상적으로 발생 — 에러가 아님
- 메시지 크기 제한이 있음

---

## 18. Epoch 및 Validator 관리

### Epoch 개념

- **Epoch**: 고정된 밸리데이터 셋이 유지되는 기간 (기본 10블록)
- **Epoch Block**: 에폭의 마지막 블록 — `EpochInfo`에 다음 에폭 정보 기록
- **Stabilizing Epoch**: 스테이커 수가 `StabilizingStakersThreshold` 미만인 초기 에폭

### Validator 선택 프로세스

1. **스테이커 등록**: GovStaking 컨트랙트에 스테이킹
2. **에폭 전환**: 에폭 마지막 블록에서 다음 밸리데이터 셋 결정
3. **Diligence 기반**: 활동 지표(시일 참여)에 따라 선택
4. **TargetValidators**: 목표 밸리데이터 수 (설정 가능)

### DPoS 모델 (go-wemix → go-wbft 전환)

| 항목 | go-wemix (PoA) | go-wbft (DPoS+BFT) |
|------|----------------|---------------------|
| 밸리데이터 선택 | 40개 NCP 고정 | 스테이킹 기반 동적 선택 |
| 합의 알고리즘 | WPoA | WBFT (QBFT 기반 BFT) |
| 블록 생성 | NCP 순서대로 | Proposer → Prepare → Commit |
| 스테이킹 | 없음 | GovStaking 컨트랙트 |
| 보안 | NCP 신뢰 | BFT 쿼럼 (2/3+) |

### Randao

WBFT는 `RandaoReveal`을 사용하여 밸리데이터 순서에 공정한 랜덤성 추가:
- `RandaoReveal`: ECDSA 서명 (chainId, 하드포크 버전, 블록 높이에 대해)
- `MixDigest`: 이전 블록과 현재 블록의 XOR

### 주요 설정값

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `RequestTimeoutSeconds` | 2 | 라운드 타임아웃 (초) |
| `BlockPeriodSeconds` | 1 | 블록 간 최소 시간 (초) |
| `EpochLength` | 10 | 에폭 길이 (블록 수) |
| `TargetValidators` | 1 | 목표 밸리데이터 수 |
| `StabilizingStakersThreshold` | 1 | 안정화 스테이커 임계값 |
| `ProposerPolicy` | 0 (RoundRobin) | 제안자 선택 방식 |
| `UseNCP` | false | NCP 사용 여부 |
