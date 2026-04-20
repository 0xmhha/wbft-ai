---
name: wbft-system-contract-workflow
description: go-wbft에서 system contract (wemixgov 거버넌스 컨트랙트 - GovConfig/GovStaking/GovRewardeeImp/GovNCP)을 추가·수정·삭제하는 엔드-투-엔드 워크플로우. Solidity 소스 작성 → compile.go로 바이트코드 빌드 → govcontracts/v{N}/에 아티팩트 배치 → governance-wbft Go 바인딩 업데이트 → params/config_wbft.go 체인 설정 확장 → core/genesis.go InjectContracts 및 consensus/wbft Finalize 경로 연동까지 레이어별 절차와 불변식을 안내한다. /wbft-review-code 명령어와 함께 사용할 때 wemixgov/, governance-wbft/govcontracts/, core/ 수정 작업을 효율화한다. 트리거 키워드 - system contract, 거버넌스 컨트랙트, GovStaking, GovConfig, GovNCP, GovRewardee, govcontracts, contracts-wbft, InjectContracts, GovContractUpgrades, CroissantConfig, 새 컨트랙트 버전, 하드포크 업그레이드.
---

# go-wbft System Contract Workflow

## 목적

go-wbft의 system contract(= 거버넌스 컨트랙트, `wemixgov/*`)를 **추가/수정/삭제**할 때 필요한 모든 레이어를 한 번에 갱신한다. go-stablenet의 `systemcontracts/`가 go-wbft에서는 `wemixgov/`로 구현되어 있으며, 제네시스(Block 0)와 런타임 하드포크(Block N) 두 진입점을 통해 체인 상태에 주입된다.

## 워크플로우 개요 (6 레이어)

```
[L1] Solidity 소스       wemixgov/governance-contract/contracts-wbft/v{N}/*.sol
         ↓ compile.go
[L2] 바이트코드 빌드     solc 0.8.14 → RuntimeCode 추출
         ↓ ExportContractCode
[L3] 아티팩트 배치       wemixgov/governance-wbft/govcontracts/v{N}/<ContractName>
         ↓ //go:embed
[L4] Go 바인딩 갱신      wemixgov/governance-wbft/{contracts,governance,staking,ncp,stateutil}.go
         ↓
[L5] 체인 설정 확장      params/config_wbft.go (GovContracts / Upgrade 타입)
         ↓
[L6] core 통합           core/genesis.go:InjectContracts (Block 0)
                         consensus/wbft/config.go:GetGovContractsStateTransition (Block N)
                         consensus/wbft/engine/engine.go:processFinalize (apply site)
```

모든 레이어에서 **단일 수렴점**은 `wemixgov/governance-wbft/governance.go:51`의 `GetGovContractsTransition()` — 제네시스와 런타임 업그레이드 둘 다 이 함수를 호출해 `params.StateTransition`(Codes + States)으로 컨트랙트 배포와 스토리지 초기화를 기술한다.

## 작업 유형별 진입

| 작업 유형 | 핵심 레이어 | 참조 문서 |
|---|---|---|
| **새 컨트랙트 추가** | L1~L6 전체 | [01-solidity-source.md](references/01-solidity-source.md) → [05-hardfork-recipe.md](references/05-hardfork-recipe.md) |
| **기존 컨트랙트 버전 업그레이드 (v1→v2)** | L1~L6 (Upgrade 항목 추가) | [05-hardfork-recipe.md](references/05-hardfork-recipe.md) |
| **Solidity 로직만 수정 (동일 버전)** | L1, L2, L3 | [01-solidity-source.md](references/01-solidity-source.md), [02-build-compile.md](references/02-build-compile.md) |
| **스토리지 슬롯 상수/State reader 수정** | L4 | [03-go-bindings.md](references/03-go-bindings.md) |
| **초기 파라미터/주소 변경 (체인 설정)** | L5 | [04-core-integration.md](references/04-core-integration.md) |
| **컨트랙트 삭제/제거** | L1~L6 + 호환성 검토 | [06-gotchas.md](references/06-gotchas.md) "삭제 시 주의" 섹션 |
| **core에서 system contract 조회 추가** | L4 state reader + 사용처 | [04-core-integration.md](references/04-core-integration.md) |

## 레이어별 필수 참조

작업 전 해당 레이어의 reference 파일을 반드시 Read한다. 파일은 독립적이므로 필요한 것만 로드한다.

- **L1 Solidity 소스**: [references/01-solidity-source.md](references/01-solidity-source.md)
- **L2 빌드 시스템**: [references/02-build-compile.md](references/02-build-compile.md)
- **L3+L4 Go 바인딩**: [references/03-go-bindings.md](references/03-go-bindings.md)
- **L5+L6 core 통합**: [references/04-core-integration.md](references/04-core-integration.md)
- **새 버전 추가 End-to-End**: [references/05-hardfork-recipe.md](references/05-hardfork-recipe.md)
- **불변식 / 주의사항 / 테스트**: [references/06-gotchas.md](references/06-gotchas.md)

## /wbft-review-code 와 결합

`/wbft-review-code` 호출 시 질문이 아래 키워드를 포함하면 이 skill의 워크플로우를 기준으로 응답한다:

- "새 컨트랙트 추가", "system contract 추가"
- "컨트랙트 버전 업그레이드", "v2 추가", "새 하드포크에서 거버넌스"
- "govcontracts 바이트코드", "contracts-wbft 컴파일"
- "InjectContracts 수정", "GovContractUpgrades 추가"
- "core에서 거버넌스 조회"

응답 형식: "어느 레이어(L1~L6)가 영향받는지 → 각 레이어의 변경 항목 → 불변식 점검 → 테스트"

## 핵심 원칙 (반드시 준수)

1. **단일 수렴점 유지**: 모든 컨트랙트 배포/초기화는 반드시 `GetGovContractsTransition()`을 통과한다. 직접 `state.SetCode`/`state.SetState` 호출을 새로 추가하지 말 것.
2. **버전 단조 증가**: `v1 → v2 → v3` 순서만 허용. `contracts.go`의 `GovContractCodes` 맵과 `contracts-wbft/compile.go`의 `versions` 슬라이스가 **동시에** 갱신되어야 한다.
3. **스토리지 슬롯 호환성**: 버전 업그레이드 시 기존 슬롯 레이아웃을 깨뜨리지 않도록 솔리디티 상태변수 선언 순서를 유지. 새 상태변수는 **끝에만 추가**.
4. **제네시스 vs 런타임 경로 동일성**: 두 경로 모두 `StateTransition`(Codes + States)로 환원되므로, 초기화 로직을 한 경로에만 추가하는 실수 금지. 런타임 업그레이드에서는 이미 배포된 컨트랙트의 스토리지가 보존된다는 점을 고려.
5. **NCP 선택성**: `GovNCP`는 `*GovContract`로 선언되어 nil 허용 (UseNCP=false인 체인용). 추가 컨트랙트도 optional이면 동일 패턴 유지.
6. **주소 영역**: `0x1000`(Config) ~ `0x1003`(NCP) 고정. 새 컨트랙트는 `0x1004` 이후 할당.

자세한 이유/반례는 [references/06-gotchas.md](references/06-gotchas.md) 참조.

## 빠른 경로: "기존 컨트랙트 로직만 수정"

v1 GovStaking의 Solidity 로직만 변경하는 최소 변경 시나리오:

1. `wemixgov/governance-contract/contracts-wbft/v1/GovStaking.sol` 편집
2. 빌드 실행:
   ```bash
   cd wemixgov/governance-contract/contracts-wbft && go run compile.go
   ```
3. `wemixgov/governance-wbft/govcontracts/v1/GovStaking` 바이트코드가 갱신됨 (Keccak 비교로 동일하면 no-op)
4. Go 테스트 실행: `go test ./wemixgov/governance-wbft/... ./consensus/wbft/...`
5. 스토리지 레이아웃이 바뀌었다면 L4의 `SLOT_*` 상수와 state reader 확인

스토리지 레이아웃/ABI가 바뀌었다면 전체 워크플로우(L1~L6) 진행 — [05-hardfork-recipe.md](references/05-hardfork-recipe.md) 참조.
