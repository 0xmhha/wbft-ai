# L3 + L4: Go 바인딩 (wemixgov/governance-wbft/)

## 목차
- 패키지 구조와 역할
- contracts.go (바이트코드 embed + 맵)
- governance.go (GetGovContractsTransition)
- staking.go / ncp.go (state reader)
- stateutil.go (storage slot 유틸)
- 체크리스트

## 패키지 구조

`wemixgov/governance-wbft/` — `package govwbft`, 5개 Go 파일 + 바이트코드 아티팩트.

| 파일 | 역할 | 수정 트리거 |
|------|------|-----------|
| `contracts.go` | `//go:embed`로 바이트코드 적재, `GovContractCodes` 맵 구성, 파라미터/슬롯 상수 | 새 컨트랙트·버전 추가 시 |
| `governance.go` | `GetGovContractsTransition()` — 배포+초기화 로직 | 새 컨트랙트, 새 초기 스토리지 |
| `staking.go` | 스테이커 state reader (IsStaker, StakerInfo, GetTotalStaked 등) | GovStaking 슬롯 변경 |
| `ncp.go` | NCP state reader (NCPList, IsNCP) | GovNCP 슬롯 변경 |
| `stateutil.go` | `CalculateMappingSlot`, `CalculateDynamicSlot`, `IncrementHash` | 거의 수정 없음 (core util) |

## contracts.go — 바이트코드 적재와 상수

역할: `//go:embed`로 `govcontracts/v{N}/<Contract>` 파일을 `string`에 적재하고, `GovContractCodes[CONTRACT_NAME][VERSION]` 맵에 등록.

### 새 컨트랙트 추가 시 필요한 편집

```go
// 1) 컨트랙트 이름 상수
const (
    CONTRACT_GOV_STAKING      = "GovStaking"
    // ... 기존
    CONTRACT_GOV_NEW_FEATURE  = "GovNewFeature"   // 신규
)

// 2) 바이트코드 embed (파일이 govcontracts/v1/GovNewFeature 경로에 존재해야 함)
var (
    //go:embed govcontracts/v1/GovStaking
    GovStakingContractV1 string
    // ... 기존
    //go:embed govcontracts/v1/GovNewFeature
    GovNewFeatureContractV1 string
)

// 3) init()에서 맵에 등록
func init() {
    GovContractCodes[CONTRACT_GOV_NEW_FEATURE] = make(map[string]string)
    GovContractCodes[CONTRACT_GOV_NEW_FEATURE][GOV_CONTRACT_VERSION_1] = GovNewFeatureContractV1
}
```

### 새 버전 추가 시 (v3)

```go
const GOV_CONTRACT_VERSION_3 = "v3"

//go:embed govcontracts/v3/GovStaking
GovStakingContractV3 string

// init()
GovContractCodes[CONTRACT_GOV_STAKING][GOV_CONTRACT_VERSION_3] = GovStakingContractV3
```

### 파라미터/슬롯 상수

`contracts.go`는 **GovConfig 파라미터 키**와 **슬롯 번호**도 관리한다:

```go
GOV_CONFIG_PARAM_MINIMUM_STAKING     = "minimumStaking"   // JSON/TOML key
SLOT_GOV_CONFIG_MINIMUM_STAKING      = "0x0"              // Solidity slot
```

이 두 상수는 `governance.go:GetGovContractsTransition()`에서 쌍으로 사용. 새 파라미터를 추가하려면 둘 다 정의하고 Solidity 상태변수 슬롯과 일치시킨다.

## governance.go — 단일 수렴점

### GetGovContractsTransition (`governance.go:51`)

입력: `*params.GovContracts`
출력: `*params.StateTransition` (= `[]CodeParam` + `[]StateParam`)

각 컨트랙트별로 `if govContracts.GovXxx != nil` 분기. nil이면 스킵. 그래서 런타임 업그레이드에서 delta만 업그레이드 가능.

### 새 컨트랙트 지원 추가 (패턴)

기존 GovConfig 블록을 참고해 다음 구조로 추가:

```go
if govContracts.GovNewFeature != nil {
    // 1) 바이트코드 배포
    st.Codes = append(st.Codes, params.CodeParam{
        Address: govContracts.GovNewFeature.Address,
        Code:    GovContractCodes[CONTRACT_GOV_NEW_FEATURE][govContracts.GovNewFeature.Version],
    })

    // 2) 초기 스토리지 슬롯 설정 (필요 시)
    someValue, _ := new(big.Int).SetString(
        govContracts.GovNewFeature.Params[GOV_NEW_FEATURE_PARAM_SOMETHING], 10)
    if someValue == nil {
        return nil, errors.New("invalid gov new feature params")
    }
    st.States = append(st.States, params.StateParam{
        Address: govContracts.GovNewFeature.Address,
        Key:     common.HexToHash(SLOT_GOV_NEW_FEATURE_SOMETHING),
        Value:   common.BigToHash(someValue),
    })

    // 3) 다른 컨트랙트 참조 주소 주입 (있다면)
    if govContracts.GovConfig != nil {
        st.States = append(st.States, params.StateParam{
            Address: govContracts.GovNewFeature.Address,
            Key:     common.HexToHash(SLOT_GOV_NEW_FEATURE_GOV_CONFIG_ADDRESS),
            Value:   common.BytesToHash(govContracts.GovConfig.Address.Bytes()),
        })
    }
}
```

### checkGovContractVersions (`governance.go:35`)

버전 유효성 검사. `params.CheckGovContractVersions` 함수포인터에 `init()`에서 바인딩(import cycle 회피). 새 컨트랙트 추가 시 여기에도 검사 추가:

```go
if GovContractCodes[CONTRACT_GOV_NEW_FEATURE][govContracts.GovNewFeature.Version] == "" {
    return fmt.Errorf("`govContracts.govNewFeature`: unsupported version %s", govContracts.GovNewFeature.Version)
}
```

nil 허용(optional) 컨트랙트는 `if govContracts.GovNewFeature != nil && ...` 패턴 사용.

## staking.go / ncp.go — state reader

### 역할

`StateDB` 읽기 전용 유틸. Solidity storage layout에 맞춰 slot을 계산하고 값을 디코드한다.

예: `IsStaker(govStakingAddress, state, addr)` 는 `SLOT_STAKER_SET`의 AddressSet에 주소가 존재하는지 확인.

### 새 컨트랙트용 state reader 추가 패턴

```go
// staking_or_newfeature.go
func NewFeatureSomeValue(contractAddr common.Address, state StateReader) *big.Int {
    raw := state.GetState(contractAddr, common.HexToHash(SLOT_GOV_NEW_FEATURE_SOMETHING))
    return new(big.Int).SetBytes(raw.Bytes())
}
```

매핑/배열 슬롯은 `stateutil.go`의 `CalculateMappingSlot`, `CalculateDynamicSlot` 사용:

```go
// mapping(address => uint256) balance;  // slot = SLOT_BALANCE
func BalanceOf(contractAddr common.Address, state StateReader, who common.Address) *big.Int {
    slot := CalculateMappingSlot(common.HexToHash(SLOT_BALANCE), who)
    raw := state.GetState(contractAddr, slot)
    return new(big.Int).SetBytes(raw.Bytes())
}
```

### StateReader 인터페이스

```go
type StateReader interface {
    GetState(common.Address, common.Hash) common.Hash
}
```

**`*state.StateDB`가 이 인터페이스를 만족**하므로, consensus/core 계층에서 자유롭게 호출 가능. 새 reader를 추가할 때도 이 인터페이스만 받도록 설계 — `*state.StateDB`를 직접 받지 말 것 (테스트 용이성 ↓).

## stateutil.go — storage slot 유틸

### 함수 3개

| 함수 | 용도 | Solidity 대응 |
|------|------|-------------|
| `CalculateMappingSlot(slot, key)` | `mapping(K => V)` 슬롯 | `keccak256(abi.encode(key, slot))` |
| `CalculateDynamicSlot(slot, index)` | 동적 배열 원소 슬롯 | `keccak256(slot) + index` |
| `IncrementHash(h, n)` | 해시를 big.Int로 보고 n 더하기 | 복합 구조체의 다음 필드 슬롯 |

이 파일은 거의 수정할 필요 없음. 새 슬롯 계산식이 필요하면 여기에 추가.

## 체크리스트 (L3+L4 수정 완료 기준)

- [ ] `contracts.go`: 상수 정의 + `//go:embed` + `init()` 맵 등록이 모두 추가됨
- [ ] `governance.go`: `GetGovContractsTransition()`의 새 분기 추가 + `checkGovContractVersions()` 검증 추가
- [ ] 필요 시 state reader 함수 추가 (`staking.go`/`ncp.go`/새 파일)
- [ ] 새 파라미터는 `GOV_*_PARAM_*` 키와 `SLOT_*` 번호가 **쌍으로** 정의됨
- [ ] `go build ./wemixgov/governance-wbft/...` 성공
- [ ] `go test ./wemixgov/governance-wbft/...` — `TestGetGovContractsTransition_*` 테스트에 새 케이스 추가 고려

## 다음 단계

- 체인 설정(L5) + core 통합(L6) → [04-core-integration.md](04-core-integration.md)
