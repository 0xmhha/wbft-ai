# End-to-End 레시피: 새 하드포크에서 system contract 업그레이드

## 시나리오

"Baguette 하드포크(블록 N)에서 GovStaking을 v2로, 새 컨트랙트 GovSlashing을 도입한다"와 같은 완전 시나리오. 아래 8단계를 **순서대로** 수행한다.

## Step 0: 설계 확정

결정해야 할 사항:
- 어떤 컨트랙트를 추가/업그레이드?
- 어느 버전(vN)을 부여?
- 적용 블록 번호?
- 신규 컨트랙트 주소 (0x1004+ 사용)
- 초기 파라미터 값

이 결정이 끝나야 아래 단계를 일관되게 진행할 수 있다. 참고: 스토리지 레이아웃 변경은 "추가 전용"만 안전 — [06-gotchas.md](06-gotchas.md) 참조.

## Step 1: Solidity 소스 작성

`wemixgov/governance-contract/contracts-wbft/v2/GovStaking.sol` 편집 (v1 대비 로직/상태변수 추가).
`wemixgov/governance-contract/contracts-wbft/v1/GovSlashing.sol` 신규 작성 (또는 v2 디렉터리에, 도입 시점에 따라).

규칙:
- 기존 상태변수 선언 순서·타입 유지
- 새 상태변수는 뒤에만 추가
- 다른 컨트랙트 참조 시 slot 기반 주소 주입 패턴 사용 (GovStaking의 GovConfig/GovRewardeeImp 주입 방식 참고)

## Step 2: 바이트코드 빌드

`wemixgov/governance-contract/contracts-wbft/compile.go`:
```go
versions := []string{
    govwbft.GOV_CONTRACT_VERSION_1,
    govwbft.GOV_CONTRACT_VERSION_2,
}
srcFiles := [][]string{
    { /* v1 기존 + */ filepath.Join(root, "v1", "GovSlashing.sol") },
    { /* v2 기존 */ },
}
contractBins := [][]string{
    { /* v1 기존 + */ govwbft.CONTRACT_GOV_SLASHING },
    { /* v2 기존 */ },
}
```

실행:
```bash
cd wemixgov/governance-contract/contracts-wbft && go run compile.go
```

## Step 3: 바이트코드 아티팩트 확인

```bash
ls wemixgov/governance-wbft/govcontracts/v1/GovSlashing
ls wemixgov/governance-wbft/govcontracts/v2/GovStaking   # 재빌드된 상태
```

git으로 변경 사항을 스테이징한다.

## Step 4: governance-wbft Go 바인딩

### `wemixgov/governance-wbft/contracts.go`

```go
const (
    CONTRACT_GOV_SLASHING = "GovSlashing"  // 신규

    // v2가 이미 있으므로 버전 상수는 추가 불필요
)

// 파라미터/슬롯 상수 추가
const (
    GOV_SLASHING_PARAM_PENALTY_RATE = "penaltyRate"
    SLOT_GOV_SLASHING_PENALTY_RATE  = "0x0"
    // ...
)

var (
    //go:embed govcontracts/v1/GovSlashing
    GovSlashingContractV1 string
)

func init() {
    // 기존 map 초기화 후
    GovContractCodes[CONTRACT_GOV_SLASHING] = make(map[string]string)
    GovContractCodes[CONTRACT_GOV_SLASHING][GOV_CONTRACT_VERSION_1] = GovSlashingContractV1
}
```

### `wemixgov/governance-wbft/governance.go`

`GetGovContractsTransition()`에 분기 추가:
```go
if govContracts.GovSlashing != nil {
    st.Codes = append(st.Codes, params.CodeParam{
        Address: govContracts.GovSlashing.Address,
        Code:    GovContractCodes[CONTRACT_GOV_SLASHING][govContracts.GovSlashing.Version],
    })
    penaltyRate, _ := new(big.Int).SetString(
        govContracts.GovSlashing.Params[GOV_SLASHING_PARAM_PENALTY_RATE], 10)
    if penaltyRate == nil {
        return nil, errors.New("invalid gov slashing params")
    }
    st.States = append(st.States, params.StateParam{
        Address: govContracts.GovSlashing.Address,
        Key:     common.HexToHash(SLOT_GOV_SLASHING_PENALTY_RATE),
        Value:   common.BigToHash(penaltyRate),
    })
}
```

`checkGovContractVersions()` 업데이트:
```go
if govContracts.GovSlashing != nil &&
    GovContractCodes[CONTRACT_GOV_SLASHING][govContracts.GovSlashing.Version] == "" {
    return fmt.Errorf("`govContracts.govSlashing`: unsupported version %s",
        govContracts.GovSlashing.Version)
}
```

### state reader (필요 시)

새 파일 `wemixgov/governance-wbft/slashing.go` 생성 — staking.go/ncp.go 패턴 복제.

## Step 5: params/config_wbft.go 확장

```go
type GovContracts struct {
    GovConfig      *GovContract `json:"govConfig"`
    GovStaking     *GovContract `json:"govStaking"`
    GovRewardeeImp *GovContract `json:"govRewardeeImp"`
    GovNCP         *GovContract `json:"govNCP"`
    GovSlashing    *GovContract `json:"govSlashing"`   // 신규
}
```

`String()`, `DefaultCroissantConfig.GovContracts` 갱신.

`CroissantConfig.CheckValidity()`: Slashing이 필수라면 nil 체크 추가. Optional이면 생략.

### 새 하드포크 블록 번호 필드

`params/config.go`의 `ChainConfig`에 추가:
```go
type ChainConfig struct {
    // ... 기존
    BaguetteBlock *big.Int `json:"baguetteBlock,omitempty"`
}

func (c *ChainConfig) IsBaguette(num *big.Int) bool {
    return isBlockForked(c.BaguetteBlock, num)
}
```

## Step 6: consensus/wbft/config.go

`Config.GetGovContracts` 콜백에 새 필드 반영:
```go
if upgrade.GovSlashing != nil { gc.GovSlashing = upgrade.GovSlashing }
```

## Step 7: 체인 설정에 Upgrade 등록

메인넷/테스트넷 genesis.json 또는 `params/config.go`의 체인 설정에 `GovContractUpgrades` 항목 추가:

```go
// consensus/wbft의 Config (TOML로도 구성 가능)
GovContractUpgrades: []params.Upgrade{
    {
        Block: big.NewInt(N),  // Baguette 블록 번호
        GovContracts: &params.GovContracts{
            GovStaking: &params.GovContract{
                Address: common.HexToAddress("0x1001"),
                Version: "v2",   // v1 → v2 업그레이드
            },
            GovSlashing: &params.GovContract{
                Address: common.HexToAddress("0x1004"),  // 새 주소
                Version: "v1",
                Params:  map[string]string{
                    "penaltyRate": "1000",
                },
            },
        },
    },
},
```

**Delta 의미**: `Upgrade.GovContracts`에 명시된 필드만 재배포된다. 업그레이드 안 하는 컨트랙트는 nil로 두면 스토리지 보존.

## Step 8: 테스트

### 단위 테스트

```bash
go test ./wemixgov/governance-wbft/...
go test ./params/...
go test ./consensus/wbft/...
go test ./core/...
```

`wemixgov/governance-wbft/governance_test.go`의 `TestGetGovContractsTransition_*`에 새 컨트랙트 케이스 추가 고려.

### 통합 테스트

- `consensus/wbft/engine/engine_test.go`에서 `GetGovContractsStateTransition` 호출 경로 테스트 추가
- 제네시스 경로: `core/chain_makers.go`와 함께 `InjectContracts`가 `GovSlashing.Code`를 alloc에 넣는지 확인

### 수동 검증

genesis_generator로 제네시스 JSON 생성 → 새 컨트랙트 주소에 Code와 Storage가 들어갔는지 확인:
```bash
./build/bin/genesis_generator -config config.toml -out genesis.json
jq '.alloc["0x0000000000000000000000000000000000001004"]' genesis.json
```

런타임 업그레이드 테스트: 블록 N까지 로컬 체인을 돌려서 Finalize 경로에서 `SetCode`/`SetState`가 호출되는지 로그 확인.

## Step 9: 빌드와 린팅

```bash
make gwemix
make test
make lint
```

## 요약 체크리스트

- [ ] Solidity 소스 작성 (v1 또는 vN 디렉터리)
- [ ] `contracts-wbft/compile.go` srcFiles/contractBins 업데이트
- [ ] 빌드 실행 → `govcontracts/v{N}/...` 아티팩트 갱신 확인 + git add
- [ ] `governance-wbft/contracts.go`: 상수 + embed + init 맵 등록
- [ ] `governance-wbft/governance.go`: `GetGovContractsTransition` 분기 + `checkGovContractVersions`
- [ ] `governance-wbft/<new>.go`: state reader (필요 시)
- [ ] `params/config_wbft.go`: `GovContracts` 구조체 + `CheckValidity` + `DefaultCroissantConfig`
- [ ] `params/config.go`: 새 하드포크 블록 필드 (필요 시)
- [ ] `consensus/wbft/config.go`: `GetGovContracts` 콜백 라인
- [ ] 체인 설정: `GovContractUpgrades` 항목 추가
- [ ] 테스트 통과 (governance_test, params, wbft, core)
- [ ] 제네시스 생성 및 genesis.json 수동 검증
- [ ] `make gwemix && make test && make lint`
