# L5 + L6: 체인 설정과 core 통합

## 목차
- L5 체인 설정 (params/config_wbft.go)
- L6 core 진입점 2개
- consensus/wbft 적용 경로
- core에서 system contract 조회 추가
- 체크리스트

## L5: params/config_wbft.go — 체인 설정 타입

**파일**: `params/config_wbft.go`

### 핵심 타입

```go
type GovContracts struct {
    GovConfig      *GovContract `json:"govConfig"`
    GovStaking     *GovContract `json:"govStaking"`
    GovRewardeeImp *GovContract `json:"govRewardeeImp"`
    GovNCP         *GovContract `json:"govNCP"`           // optional
    // 새 컨트랙트는 여기에 *GovContract 포인터로 추가
}

type GovContract struct {
    Address common.Address    `json:"address"`
    Version string            `json:"version"`
    Params  map[string]string `json:"params"`
}

type Upgrade struct {
    Block         *big.Int `json:"block"`
    *GovContracts `json:"govContracts"`      // 포인터 필드만 실린 delta
}

type CodeParam  struct { Address common.Address; Code string }
type StateParam struct { Address common.Address; Key, Value common.Hash }
type StateTransition struct { Codes []CodeParam; States []StateParam }
```

### 새 컨트랙트를 `GovContracts`에 추가

```go
type GovContracts struct {
    GovConfig      *GovContract `json:"govConfig"`
    GovStaking     *GovContract `json:"govStaking"`
    GovRewardeeImp *GovContract `json:"govRewardeeImp"`
    GovNCP         *GovContract `json:"govNCP"`
    GovNewFeature  *GovContract `json:"govNewFeature"`    // 신규
}
```

`String()` 메서드도 함께 갱신.

### CroissantConfig.CheckValidity()

필수(required) 컨트랙트라면 다음 체크를 추가:

```go
if c.GovContracts.GovNewFeature == nil {
    return errors.New("`croissant.govContracts`: missing `govNewFeature`")
}
```

Optional이라면 추가하지 말 것 (nil 허용).

### DefaultCroissantConfig

테스트/기본 설정용 기본값. 새 컨트랙트도 여기에 예시값 제공:

```go
GovNewFeature: &GovContract{
    Address: common.HexToAddress("0x1004"),
    Version: "v1",
    Params:  map[string]string{ /* ... */ },
},
```

### consensus/wbft/config.go — Config.GetGovContracts

**파일**: `consensus/wbft/config.go:132`

```go
func (c *Config) GetGovContracts(blockNumber *big.Int, chainConfig *params.ChainConfig) params.GovContracts {
    gc := params.GovContracts{}
    if len(c.GovContractUpgrades) > 0 {
        c.getGovContractsValue(blockNumber, func(upgrade params.Upgrade) {
            if upgrade.GovStaking != nil    { gc.GovStaking = upgrade.GovStaking }
            if upgrade.GovConfig != nil     { gc.GovConfig = upgrade.GovConfig }
            // ...
        })
    }
    return gc
}
```

새 필드 추가 시 이 함수의 콜백에도 nil 체크와 덮어쓰기 라인을 추가:

```go
if upgrade.GovNewFeature != nil { gc.GovNewFeature = upgrade.GovNewFeature }
```

## L6: core 진입점 2개

### (1) 제네시스 — core/genesis.go:718 InjectContracts

```go
func InjectContracts(genesis *Genesis, config *params.ChainConfig) error {
    transition, err := govwbft.GetGovContractsTransition(config.Croissant.GovContracts)
    if err != nil { return err }
    if transition == nil {
        return errors.New("Some or all of the Croissant parameters are missing...")
    }
    if genesis.Alloc == nil {
        genesis.Alloc = map[common.Address]types.Account{}
    }
    for _, c := range transition.Codes {
        genesis.Alloc[c.Address] = types.Account{
            Code: hexutil.MustDecode(c.Code), Balance: common.Big0,
            Storage: make(map[common.Hash]common.Hash),
        }
    }
    for _, s := range transition.States {
        genesis.Alloc[s.Address].Storage[s.Key] = s.Value
    }
    return nil
}
```

- 호출처 (검색 `InjectContracts`):
  - `core/genesis.go:248` — `SetupGenesisBlock`에서 Croissant 체인 설정이면 호출
  - `core/chain_makers.go:433` — 테스트 체인 메이커
  - `consensus/wbft/testutils/genesis.go:71` — WBFT 테스트 유틸

**새 컨트랙트를 추가해도 `InjectContracts` 자체는 수정 불필요** — 모든 배포/초기화는 `GetGovContractsTransition()`에서 이미 처리되므로 이 함수는 `StateTransition`을 받아 state에 기계적으로 붓기만 한다.

### (2) 런타임 — consensus/wbft/config.go:220 + engine.go:892

```go
// consensus/wbft/config.go
func GetGovContractsStateTransition(wbftCfg *Config, num *big.Int) (*params.StateTransition, error) {
    for _, upgrade := range wbftCfg.GovContractUpgrades {
        if num.Cmp(upgrade.Block) == 0 {
            return govwbft.GetGovContractsTransition(upgrade.GovContracts)
        } else if num.Cmp(upgrade.Block) < 0 {
            break
        }
    }
    return nil, nil
}
```

조건:
- 업그레이드는 **해당 블록 번호 정확히 일치**해야 적용 (`num.Cmp == 0`)
- `GovContractUpgrades`는 블록 번호 오름차순 정렬 가정

```go
// consensus/wbft/engine/engine.go:892 (processFinalize 내부)
if st, err := wbft.GetGovContractsStateTransition(e.cfg, header.Number); err != nil {
    return err
} else if st != nil {
    for _, c := range st.Codes {
        state.SetCode(c.Address, hexutil.MustDecode(c.Code))
    }
    for _, s := range st.States {
        state.SetState(s.Address, s.Key, s.Value)
    }
}
```

**`Finalize` 단계에서 실행** — 블록 실행 후 state를 확정하기 직전. 이 점이 중요: 트랜잭션 실행 결과를 덮어써서라도 업그레이드가 적용된다.

### 새 컨트랙트가 core 통합에 미치는 영향

- `InjectContracts`, `GetGovContractsStateTransition`, `processFinalize` **세 함수 모두 수정 불필요**
- 단, `GetGovContracts`(`config.go:132`)의 누적 로직 콜백에 새 필드 반영 필요
- `CroissantConfig.CheckValidity()`에 필수 검증 추가 (필수 컨트랙트일 때만)

## core/ 코드에서 system contract 조회 추가

새로운 core 로직(합의, 블록 보상, 트랜잭션 후처리 등)이 system contract 상태를 읽어야 한다면:

1. `wemixgov/governance-wbft/`에 state reader 함수가 있는지 먼저 확인
2. 없으면 L4(`03-go-bindings.md`) 패턴으로 `StateReader` 인터페이스를 받는 reader 추가
3. core에서 호출:
   ```go
   import govwbft "github.com/ethereum/go-ethereum/wemixgov/governance-wbft"

   govContracts := e.cfg.GetGovContracts(header.Number, chainConfig)
   totalStake := govwbft.NCPTotalStaking(
       govContracts.GovStaking.Address,
       govContracts.GovNCP.Address,
       state,
   )
   ```
4. 주소는 항상 `GetGovContracts(blockNumber, ...)`로 해당 블록 기준 활성 주소를 얻는다. 하드코딩 금지.

### core에서 직접 `state.SetCode/SetState` 금지

system contract의 상태를 core에서 변경해야 한다면 **반드시** L4 Go 바인딩을 거치거나, 정말 합의 레벨의 결정이라면 `GovContractUpgrades`에 항목을 추가해 `Finalize` 경로로 처리. 임시방편으로 core에서 직접 쓰면 제네시스/런타임 경로 일관성이 깨진다.

## 체크리스트 (L5+L6 수정 완료 기준)

- [ ] `params/config_wbft.go`: `GovContracts` 구조체에 새 필드 추가 + `String()` 갱신
- [ ] `CroissantConfig.CheckValidity()`: 필수 필드면 nil 체크 추가
- [ ] `DefaultCroissantConfig`: 기본값 제공
- [ ] `consensus/wbft/config.go:GetGovContracts`: 누적 로직 콜백 라인 추가
- [ ] `core/genesis.go:InjectContracts` — 수정 **없음** (단일 수렴점 원칙)
- [ ] `consensus/wbft/engine/engine.go:processFinalize` — 수정 **없음**
- [ ] 새 하드포크 블록 번호가 필요하면 `params/config.go`에 필드 추가 (Brioche/Croissant와 유사 패턴)
- [ ] 체인 설정 JSON/TOML(genesis.json, testnet 설정)에 새 필드 값 채우기
- [ ] `go build ./...` + `go test ./core/... ./consensus/wbft/... ./params/...` 통과

## 다음 단계

- End-to-End 신규 하드포크 시나리오 → [05-hardfork-recipe.md](05-hardfork-recipe.md)
- 불변식 / 자주 하는 실수 → [06-gotchas.md](06-gotchas.md)
