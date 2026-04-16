# go-wbft 고유 기능 (§8-§13)

> 거버넌스 컨트랙트, 하드포크, Fee Delegation, Brioche Halving, 솔리디티 컨트랙트, 이전 합의.

---

## 8. 거버넌스 컨트랙트

go-wbft의 거버넌스는 `wemixgov/` 패키지를 통해 구현된다. go-stablenet의 `systemcontracts/`에 해당하는 역할.

### 컨트랙트 목록

| 이름 | 기본 주소 | 역할 |
|------|-----------|------|
| GovConfig | `0x1000` | 스테이킹 파라미터 설정 (최소/최대 스테이킹, 언본딩 기간 등) |
| GovStaking | `0x1001` | 스테이킹 관리 (등록, 위임, 해제) |
| GovRewardeeImp | `0x1002` | 블록 리워드 분배 구현 |
| GovNCP | `0x1003` | NCP(Network Council Point) 관리 |

### GovConfig 기본 파라미터

| 파라미터 | 기본값 | 설명 |
|----------|--------|------|
| minimumStaking | 10,000,000 WMX | 최소 스테이킹 금액 |
| maximumStaking | 100,000,000 WMX | 최대 스테이킹 금액 |
| unbondingPeriodStaker | 604,800초 (7일) | 스테이커 언본딩 기간 |
| unbondingPeriodDelegator | 259,200초 (3일) | 위임자 언본딩 기간 |
| feePrecision | 10,000 (0.01%) | 수수료 정밀도 |
| changeFeeDelay | 604,800초 (7일) | 수수료 변경 지연 |

### 패키지 구조

```
wemixgov/
  govapi.go                       ← GovContractApi, GovBackend 인터페이스 정의
  bind/                           ← ABI 바인딩 (자동 생성, 수정 금지)
  cli/govcli.go                   ← 거버넌스 CLI
  governance-wbft/
    contracts.go                  ← 바이트코드 상수 (go:embed), 버전 매핑
    governance.go                 ← 버전 검증, GetGovContractsTransition()
    staking.go                    ← 스테이킹 상태 읽기/쓰기 함수
    ncp.go                        ← NCP 리스트, NCPStakers(), NCPTotalStaking()
    stateutil.go                  ← 슬롯 계산 유틸리티 (CalculateMappingSlot 등)
    govcontracts/v1/              ← v1 바이트코드 아티팩트 (GovStaking, GovConfig, GovRewardeeImp, GovNCP)
    govcontracts/v2/              ← v2 바이트코드 아티팩트 (GovStaking)
```

### 컨트랙트 바이트코드 등록

파일: `wemixgov/governance-wbft/contracts.go`

```go
//go:embed govcontracts/v1/GovStaking
GovStakingContractV1 string

// init()에서 GovContractCodes 맵에 등록
GovContractCodes[CONTRACT_GOV_STAKING][GOV_CONTRACT_VERSION_1] = GovStakingContractV1
```

---

## 9. 하드포크 히스토리

### go-wbft 하드포크 체인

```
Ethereum 기본 하드포크 → Pangyo → Applepie → Brioche → Croissant(WBFT)
```

| 하드포크 | 역할 | ChainConfig 필드 |
|----------|------|-------------------|
| Pangyo | WEMIX 커스텀 포크 | `PangyoBlock` |
| Applepie | WEMIX 기능 추가 | `ApplepieBlock` |
| Brioche | 블록 리워드 halving | `BriocheBlock` + `BriocheConfig` |
| **Croissant** | **WBFT 합의 전환** | `CroissantBlock` + `CroissantConfig` |

### CroissantConfig 구조

파일: `params/config_wbft.go`

```go
type CroissantConfig struct {
    WBFT         *WBFTConfig   // WBFT 합의 파라미터
    Init         *WbftInit     // 초기 밸리데이터 + BLS 키
    GovContracts *GovContracts // 초기 거버넌스 컨트랙트
}
```

### 하드포크 추가 시 주의사항

- 블록 번호는 반드시 단조 증가해야 함
- `CroissantConfig.CheckValidity()`에서 필수 필드 검증
- 밸리데이터 수와 BLS 키 수가 일치해야 함
- EpochLength ≥ TargetValidators 이어야 함

---

## 10. Fee Delegation

go-wbft는 수수료 위임 트랜잭션을 지원한다.

### 관련 파일

| 파일 | 역할 |
|------|------|
| `core/types/transaction_signing.go` | 수수료 위임 서명 처리 |
| `core/state_transition.go` | Fee Delegation 실행, 블랙리스트 검증 |

### 동작 원리

- 트랜잭션 발신자(Sender)와 수수료 납부자(FeePayer)가 분리
- 양쪽 모두 서명 필요 (이중 서명 모델)
- `core/state_transition.go`에서 FeePayer로부터 가스비 차감

---

## 11. Brioche Halving

파일: `params/config.go` (BriocheConfig), `eth/api_wemix.go`

### BriocheConfig 구조

```go
type BriocheConfig struct {
    BlockReward       *big.Int  // 기본 블록 리워드 (nil이면 기본값 1e18)
    FirstHalvingBlock *big.Int  // 첫 halving 블록 (nil이면 halving 비활성)
}
```

### 동작

- `GetBriocheBlockReward(defaultReward, blockNumber)` — 블록 번호에 따른 halving 적용 리워드 반환
- halving 주기마다 블록 리워드가 절반으로 감소

### RPC API

- `wemix_briocheConfig` — Brioche halving 설정 조회
- `wemix_halvingSchedule` — halving 스케줄 목록
- `wemix_getBriocheBlockReward(number)` — 특정 블록의 리워드

---

## 12. 솔리디티 컨트랙트

### 디렉토리 구조

```
wemixgov/governance-contract/
  contracts/                ← go-wemix용 (이전 버전)
    Gov.sol                 — 거버넌스 프록시
    GovImp.sol              — 거버넌스 구현 (46KB)
    TestnetGovImp.sol       — 테스트넷 변형 (33KB)
    Staking.sol             — 스테이킹 프록시
    StakingImp.sol          — 스테이킹 구현 (14KB)
    Registry.sol            — 주소 레지스트리
    NCPExit.sol / NCPExitImp.sol — NCP 탈퇴 관리
    GovChecker.sol          — 거버넌스 체커
    abstract/               — 추상 베이스 컨트랙트
    interface/              — 컨트랙트 인터페이스
    storage/                — 스토리지 레이아웃
    openzeppelin/           — OpenZeppelin 라이브러리

  contracts-wbft/           ← go-wbft용 (현재 버전)
    v1/
      GovConfig.sol         — 설정 파라미터 컨트랙트
      GovStaking.sol        — WBFT 스테이킹 로직
      GovRewardee.sol       — 리워드 프록시
      GovRewardeeImp.sol    — 리워드 구현
      GovNCP.sol            — NCP 관리
      IGovCouncil.sol       — 거버넌스 의회 인터페이스
      IFeeRecipient.sol     — 수수료 수령자 인터페이스
      IMultiSigWallet.sol   — 멀티시그 지갑 인터페이스
      OperatorSample.sol    — 오퍼레이터 샘플
    v2/
      GovStaking.sol        — v2 개선된 스테이킹
```

### 구분 기준

| 디렉토리 | 대상 | 설명 |
|----------|------|------|
| `contracts/` | go-wemix | PoA 기반 40개 NCP 거버넌스 |
| `contracts-wbft/` | go-wbft | DPoS 기반 스테이킹 거버넌스 |

---

## 13. 이전 합의 (wpoa)

go-wemix에서 사용하던 PoA(Weighted Proof of Authority) 합의.

### 패키지: `consensus/wpoa/`

| 파일 | 역할 |
|------|------|
| `consensus.go` | wpoa 합의 엔진 구현 |
| `gov.go` | 거버넌스 연동 (go-wemix NCP 기반) |
| `wemix_info.go` | WEMIX 체인 정보 |
| `eip1559_wemix.go` | WEMIX EIP-1559 변형 |
| `lrucache.go` | LRU 캐시 유틸 |
| `fake.go` | 테스트용 페이크 엔진 |

### go-wemix vs go-wbft 비교

| 항목 | go-wemix (wpoa) | go-wbft (wbft) |
|------|------------------|----------------|
| 합의 방식 | PoA — 40개 NCP가 순서대로 블록 생성 | DPoS+BFT — 스테이킹 기반 밸리데이터 |
| 밸리데이터 | 40개 고정 NCP | 스테이킹 기반 동적 선택 |
| 보안 모델 | NCP 신뢰 | BFT 쿼럼 (2/3+) |
| 블록 확정 | 즉시 (단일 서명자) | PrePrepare → Prepare → Commit |
| 거버넌스 | Gov/Staking/Registry 컨트랙트 | GovConfig/GovStaking/GovRewardee/GovNCP |
| 거버넌스 주소 | 별도 레지스트리 | 고정 주소 (0x1000-0x1003) |
| 하드포크 | Pangyo, Applepie, Brioche | + Croissant (WBFT 활성화) |

### Croissant 블록 이전 처리

- `CroissantBlock` 이전: wpoa 합의 엔진이 블록 처리
- `CroissantBlock` 이후: wbft 합의 엔진이 블록 처리
- 엔진 전환은 `params.ChainConfig.IsCroissant(blockNumber)`로 판정
