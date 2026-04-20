# L2: 바이트코드 빌드 (contracts-wbft/compile.go)

## 목차
- 빌드 엔트리포인트
- 빌드 실행 명령
- compile.go 구조
- 새 컨트랙트 빌드 포함
- 새 버전 디렉터리 추가
- 산출물 검증

## 빌드 엔트리포인트

**파일**: `wemixgov/governance-contract/contracts-wbft/compile.go` (`package main`)

역할: 버전별로 Solidity 소스를 솔리디티 컴파일러(solc 0.8.14)에 넘기고 RuntimeCode를 `governance-wbft/govcontracts/v{N}/<ContractName>` 경로로 내보낸다.

## 빌드 실행 명령

```bash
cd wemixgov/governance-contract/contracts-wbft
go run compile.go

# 또는 플래그 명시
go run compile.go --root ../contracts-wbft --openZeppelin ../contracts
```

성공 시 `success!` 출력. solc 바이너리가 없으면 `solcdownloader`가 `~/.solc-bin/solc-0.8.14`를 자동 다운로드.

## compile.go 구조 (`contracts-wbft/compile.go`)

```go
var (
    rootFlag         = flag.String("root", "../contracts-wbft", "")
    openZeppelinFlag = flag.String("openZeppelin", "../contracts", "")
)

func main() {
    flag.Parse()
    root := *rootFlag
    versions := []string{govwbft.GOV_CONTRACT_VERSION_1, govwbft.GOV_CONTRACT_VERSION_2}
    srcFiles := [][]string{
        { // v1
            filepath.Join(root, versions[0], "GovStaking.sol"),
            filepath.Join(root, versions[0], "GovNCP.sol"),
            filepath.Join(root, versions[0], "GovConfig.sol"),
            filepath.Join(root, versions[0], "GovRewardee.sol"),
            filepath.Join(root, versions[0], "GovRewardeeImp.sol"),
            filepath.Join(root, versions[0], "OperatorSample.sol"),
        },
        { // v2
            filepath.Join(root, versions[1], "GovStaking.sol"),
        },
    }
    contractBins := [][]string{
        { // v1
            govwbft.CONTRACT_GOV_STAKING, govwbft.CONTRACT_GOV_NCP,
            govwbft.CONTRACT_GOV_CONFIG, govwbft.CONTRACT_GOV_REWARDEE,
            govwbft.CONTRACT_GOV_REWARDEE_IMP, govwbft.CONTRACT_OPERATOR_SAMPLE,
        },
        { // v2
            govwbft.CONTRACT_GOV_STAKING,
        },
    }
    // 루프 돌면서 Compile → ExportContractCode(codeDir, contractBins[i])
}
```

- `srcFiles[i]`: 컴파일 대상 소스 파일 목록
- `contractBins[i]`: **산출물로 저장할 컨트랙트 이름 목록** (소스에 다른 컨트랙트/인터페이스가 포함돼도 여기 나열된 것만 파일로 내보냄)
- 산출물 경로: `governance-wbft/govcontracts/v{N}/<ContractName>` (확장자 없음)

## 내부 동작

1. **solc 호출** (`compiler.go:40 Compile`):
   - `--combined-json bin,bin-runtime,srcmap,...,abi,userdoc,devdoc,metadata,hashes`
   - `--optimize`
   - `--allow-paths .,./,../`
   - remapping: `@openzeppelin/contracts/`, `@openzeppelin/contracts-upgradeable/`
2. **컨트랙트 파싱**: `compiler.ParseCombinedJSON`으로 맵 구성 (`fullPath:Name` → `*compiler.Contract`), 짧은 이름(`Name`)으로 정규화
3. **RuntimeCode 추출**: `ExportContractCode`가 `contract.RuntimeCode`(= bin-runtime)를 파일로 저장
4. **멱등성**: `writeFile`이 기존 파일과 Keccak256 비교해 동일하면 write 스킵 → **diff 없는 빌드는 no-op**

## 새 컨트랙트를 빌드에 포함시키기

v1에 `GovNewFeature.sol`을 추가했다면:

1. `contracts-wbft/compile.go`의 `srcFiles[0]`에 `filepath.Join(root, versions[0], "GovNewFeature.sol")` 추가
2. `contractBins[0]`에 `govwbft.CONTRACT_GOV_NEW_FEATURE` 추가 (이 상수는 L4 `contracts.go`에 정의)
3. `wemixgov/governance-wbft/contracts.go`에 상수 추가:
   ```go
   const CONTRACT_GOV_NEW_FEATURE = "GovNewFeature"
   ```
4. 빌드 실행 → `govcontracts/v1/GovNewFeature` 생성 확인

## 새 버전 디렉터리 추가 (v3)

1. `contracts-wbft/v3/` 디렉터리 생성 + 변경 컨트랙트 배치
2. `governance-wbft/contracts.go`에 `GOV_CONTRACT_VERSION_3 = "v3"` 상수 추가
3. `contracts-wbft/compile.go` 수정:
   - `versions` 슬라이스에 `govwbft.GOV_CONTRACT_VERSION_3` 추가
   - `srcFiles`에 v3 소스 배열 추가
   - `contractBins`에 v3 산출물 이름 배열 추가
4. 빌드 실행

## 산출물 검증

```bash
# 바이트코드 파일이 생성되었는지 확인
ls wemixgov/governance-wbft/govcontracts/v1/ wemixgov/governance-wbft/govcontracts/v2/

# 파일 내용은 hex string (0x 접두어 없음 — RuntimeCode 원본)
head -c 32 wemixgov/governance-wbft/govcontracts/v1/GovStaking
```

산출물은 `//go:embed`로 `contracts.go`에 적재되므로(`L3`), 빌드 후에는 Go 빌드도 성공해야 한다:

```bash
go build ./wemixgov/governance-wbft/...
go test ./wemixgov/governance-wbft/...
```

## 주의

- **`//go:embed` 경로는 상대경로 고정**: `govcontracts/v1/GovStaking` 같은 경로가 `contracts.go` 내부에 하드코딩돼 있으므로, 바이트코드 파일명이 정확히 컨트랙트 이름과 일치해야 한다.
- **빌드 산출물은 반드시 커밋**: `govcontracts/v*/` 아래 아티팩트는 바이너리의 일부가 되므로(Go embed) git에 커밋해야 한다.
- **솔리디티 소스 변경 없이 산출물만 수정 금지**: reproducibility를 깨뜨린다. 항상 L1 변경 → L2 빌드 순서 준수.

## 다음 단계

- Go 바인딩 (contracts.go의 embed/맵 + state reader) → [03-go-bindings.md](03-go-bindings.md)
