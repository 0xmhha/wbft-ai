# 거버넌스 컨트랙트 배포/업그레이드 흐름 (§1-§6)

> wemixgov 거버넌스 컨트랙트의 배포, 버저닝, 업그레이드 상세 흐름.
>
> **수정 작업이면 skill을 우선 사용**: 컨트랙트 추가·수정·삭제, 새 버전 도입, 새 하드포크에서의 업그레이드 같은 **system contract 변경 작업**은 `wbft-system-contract-workflow` skill의 레이어별(L1~L6) 절차를 따른다. 본 문서는 **흐름 이해와 조회용 레퍼런스**이며, 실제 수정 시 단일 수렴점(`GetGovContractsTransition`) 누락·스토리지 레이아웃 파손 같은 실수가 반복되기 쉬우므로 skill의 불변식 체크리스트를 우회하지 않는다.

---

## 1. 핵심 데이터 구조

파일: `params/config_wbft.go`

### CroissantConfig (최상위 WBFT 설정)

```go
type CroissantConfig struct {
    WBFT         *WBFTConfig   // WBFT 합의 파라미터
    Init         *WbftInit     // 초기 밸리데이터 + BLS 키
    GovContracts *GovContracts // 초기 거버넌스 컨트랙트
}
```

### WbftInit (초기화)

```go
type WbftInit struct {
    Validators    []common.Address // 초기 밸리데이터 주소 (순서 중요)
    BLSPublicKeys []string         // BLS 공개키 (밸리데이터와 동일 순서)
}
```

### GovContracts (거버넌스 컨트랙트 집합)

```go
type GovContracts struct {
    GovConfig      *GovContract // 0x1000: 설정 파라미터
    GovStaking     *GovContract // 0x1001: 스테이킹 관리
    GovRewardeeImp *GovContract // 0x1002: 리워드 분배
    GovNCP         *GovContract // 0x1003: NCP 관리 (선택)
}
```

### GovContract (개별 컨트랙트)

```go
type GovContract struct {
    Address common.Address    // 배포 주소
    Version string            // "v1", "v2"
    Params  map[string]string // 초기 파라미터 (GovConfig용)
}
```

### Upgrade (런타임 업그레이드)

```go
type Upgrade struct {
    Block         *big.Int      // 업그레이드 활성화 블록
    *GovContracts               // 업그레이드할 컨트랙트 (nil이면 변경 없음)
}
```

### StateTransition (상태 전환)

```go
type StateTransition struct {
    Block  *big.Int      // 적용 블록
    Codes  []CodeParam   // 배포할 바이트코드 목록
    States []StateParam  // 설정할 스토리지 슬롯 목록
}
```

---

## 2. 제네시스 초기화 (Block 0)

### 흐름

```
ChainConfig.Croissant.GovContracts
  → core/wemix_genesis.go: InjectContracts()
    → governance-wbft/governance.go: GetGovContractsTransition()
      → 각 컨트랙트에 대해:
         1. 바이트코드 배포 (CodeParam)
         2. 초기 스토리지 설정 (StateParam)
```

### GetGovContractsTransition 세부 동작

파일: `wemixgov/governance-wbft/governance.go`

1. **GovConfig**: 바이트코드 배포 + 7개 스토리지 슬롯 초기화 (minimumStaking, maximumStaking, unbondingPeriodStaker, unbondingPeriodDelegator, feePrecision, changeFeeDelay, govCouncil)
2. **GovStaking**: 바이트코드 배포 + BLS PoP 프리컴파일 주소 + GovConfig/GovRewardeeImp 주소 설정
3. **GovRewardeeImp**: 바이트코드 배포
4. **GovNCP** (선택): 바이트코드 배포 + NCP 리스트 초기화 (배열 슬롯 + 매핑 슬롯)

### GovConfig 스토리지 슬롯 매핑

| 슬롯 | 파라미터 |
|------|----------|
| 0x0 | minimumStaking |
| 0x1 | maximumStaking |
| 0x2 | unbondingPeriodStaker |
| 0x3 | unbondingPeriodDelegator |
| 0x4 | feePrecision |
| 0x5 | changeFeeDelay |
| 0x6 | govCouncil |

---

## 3. 런타임 업그레이드 (Block N)

### 흐름

```
wbft.Config.GovContractUpgrades (블록별 업그레이드 목록)
  → consensus/wbft/config.go: GetGovContractsStateTransition(config, blockNumber)
    → 해당 블록의 Upgrade 항목 검색
      → governance-wbft/governance.go: GetGovContractsTransition()
        → StateTransition (코드 + 상태) 반환
          → Finalize 단계에서 적용
```

### Config.GetGovContracts() — 블록별 활성 컨트랙트 조회

파일: `consensus/wbft/config.go`

```go
func (c *Config) GetGovContracts(blockNumber *big.Int, chainConfig *params.ChainConfig) params.GovContracts {
    // GovContractUpgrades를 순회하며 blockNumber 이하인 업그레이드를 누적 적용
    // 각 필드가 nil이 아닌 경우에만 덮어씀
}
```

### Config.GetConfig() — 블록별 합의 파라미터 조회

```go
func (c Config) GetConfig(blockNumber *big.Int) Config {
    // Transitions를 순회하며 blockNumber 이하인 전환을 누적 적용
    // RequestTimeout, BlockPeriod, Epoch, BlockReward, TargetValidators 등
}
```

---

## 4. 컨트랙트 버저닝

### 규칙

- v1은 초기화 시 필수
- 버전은 단조 증가 (v1 → v2)
- 버전에 따라 다른 바이트코드 로드

### 바이트코드 관리

파일: `wemixgov/governance-wbft/contracts.go`

```go
// go:embed로 바이트코드 파일 로드
//go:embed govcontracts/v1/GovStaking
GovStakingContractV1 string

// GovContractCodes 맵에 등록
GovContractCodes[CONTRACT_GOV_STAKING][GOV_CONTRACT_VERSION_1] = GovStakingContractV1
GovContractCodes[CONTRACT_GOV_STAKING][GOV_CONTRACT_VERSION_2] = GovStakingContractV2
```

### 버전 검증

파일: `wemixgov/governance-wbft/governance.go`

```go
func checkGovContractVersions(govContracts *params.GovContracts) error {
    // 각 컨트랙트의 버전이 GovContractCodes에 등록되어 있는지 확인
}
```

### 현재 지원 버전

| 컨트랙트 | v1 | v2 |
|----------|----|----|
| GovConfig | O | - |
| GovStaking | O | O |
| GovRewardeeImp | O | - |
| GovNCP | O | - |

---

## 5. 새 하드포크 추가

> **실제 구현 시**: `wbft-system-contract-workflow` skill의 `references/05-hardfork-recipe.md`(End-to-End 8단계 레시피)를 따른다. 본 섹션은 흐름 이해를 돕는 요약이며, skill 쪽이 최신 체크리스트·불변식·테스트 가이드를 포함한다.

거버넌스 컨트랙트 업그레이드가 포함된 새 하드포크를 추가하는 단계:

### 단계 1: 솔리디티 컨트랙트 준비

- `wemixgov/governance-contract/contracts-wbft/v{N}/` 에 새 버전 작성
- 컴파일하여 바이트코드 생성

### 단계 2: 바이트코드 등록

- `wemixgov/governance-wbft/govcontracts/v{N}/` 에 바이트코드 파일 배치
- `contracts.go`에 `go:embed` 추가 및 `GovContractCodes` 맵에 등록

### 단계 3: ChainConfig 업데이트

- `params/config.go`에 새 하드포크 블록 필드 추가
- `params/config_wbft.go`에 필요시 새 구조체/필드 추가

### 단계 4: 체인 설정에 Upgrade 추가

- `CroissantConfig`에 새 `Upgrade` 항목 설정
- 또는 `GovContractUpgrades`에 새 항목 추가

### 단계 5: 제네시스/테스트넷 설정 업데이트

- 메인넷/테스트넷 체인 설정에 새 하드포크 블록 번호 설정

---

## 6. 파일 참조표

| 파일 | 역할 |
|------|------|
| `params/config.go` | ChainConfig — CroissantBlock, BriocheBlock 필드 |
| `params/config_wbft.go` | CroissantConfig, WBFTConfig, GovContracts, Upgrade, Transition, StateTransition |
| `consensus/wbft/config.go` | Config — GetConfig(), GetGovContracts(), GetGovContractsStateTransition() |
| `core/wemix_genesis.go` | WEMIX 제네시스 초기화 — InjectContracts() |
| `core/genesis.go` | 표준 제네시스 처리 (CroissantConfig 연동) |
| `wemixgov/govapi.go` | GovContractApi, GovBackend 인터페이스 |
| `wemixgov/governance-wbft/contracts.go` | 바이트코드 상수, GovContractCodes 맵, 버전 상수 |
| `wemixgov/governance-wbft/governance.go` | GetGovContractsTransition(), checkGovContractVersions() |
| `wemixgov/governance-wbft/staking.go` | 스테이킹 상태 읽기/쓰기 함수 |
| `wemixgov/governance-wbft/ncp.go` | NCP 리스트 관리, NCPStakers(), initializeNCP() |
| `wemixgov/governance-wbft/stateutil.go` | CalculateMappingSlot(), CalculateDynamicSlot(), IncrementHash() |
