# L1: Solidity 소스 (wemixgov/governance-contract/contracts-wbft/)

## 목차
- 디렉터리 레이아웃
- 소스 파일 추가/수정/삭제
- solc 버전 / OpenZeppelin 경로
- 인터페이스와 실행 계약

## 디렉터리 레이아웃

```
wemixgov/governance-contract/
├── contracts/                      # go-wemix (wpoa) 시대 컨트랙트
├── contracts-wbft/                 # go-wbft 전용 (WBFT 합의)
│   ├── v1/                         # 최초 배포 버전
│   │   ├── GovConfig.sol           # 거버넌스 파라미터 (minStaking, fee 등)
│   │   ├── GovStaking.sol          # 스테이킹/delegation 관리
│   │   ├── GovRewardee.sol         # 리워드 수령자 엔드포인트
│   │   ├── GovRewardeeImp.sol      # 리워드 수령자 구현
│   │   ├── GovNCP.sol              # Network Council Point 관리 (optional)
│   │   ├── OperatorSample.sol      # 참조용 샘플 (빌드엔 포함되나 체인엔 주입되지 않음)
│   │   ├── IFeeRecipient.sol       # 인터페이스
│   │   ├── IGovCouncil.sol         # 인터페이스
│   │   └── IMultiSigWallet.sol     # 인터페이스
│   ├── v2/                         # 업그레이드된 버전만 포함 (delta 방식)
│   │   └── GovStaking.sol          # v2에서 업그레이드된 컨트랙트만
│   ├── compile.go                  # 빌드 엔트리포인트
│   └── remappings.txt
├── compiler.go                     # solc 래퍼
└── solcdownloader/                 # solc 자동 다운로드
```

**중요**: `v2/`는 **변경된 컨트랙트만** 배치한다. v1에서 바뀌지 않은 컨트랙트는 v2에 복제하지 않는다. 런타임 업그레이드 시 `GovContractUpgrades[i].GovContracts`가 nil 아닌 필드만 재배포하므로, delta 스타일이 그대로 유지된다.

## 소스 파일 추가/수정/삭제 규칙

### 새 컨트랙트 추가 (예: `GovNewFeature.sol`)

1. `contracts-wbft/v1/GovNewFeature.sol` 생성 (또는 도입 하드포크 버전에 배치)
2. Solidity 상수와 상태 변수 슬롯을 Go 쪽과 일치시킨다. 슬롯은 `governance-wbft/*.go`에 `SLOT_*` 상수로 복제된다.
3. 인터페이스 의존 시 `I*.sol` 파일을 같은 버전 디렉터리에 함께 둔다.
4. [02-build-compile.md](02-build-compile.md) L2 절차로 연결.

### 기존 컨트랙트 수정 (동일 버전)

- 스토리지 레이아웃을 **절대 변경 금지** (슬롯 순서/타입 유지)
- 함수 시그니처 변경 시 호출처(다른 컨트랙트, Go 측 ABI 바인딩)를 동시 수정
- v1의 bugfix처럼 최소 변경이라면 L1 → L2만 다시 실행

### 버전 업그레이드 (v1 → v2)

- v2 디렉터리에 **변경된 컨트랙트만** 추가
- 기존 상태변수 순서·타입은 유지, **추가는 끝에만** (append-only)
- 새로 추가한 상태변수는 런타임 업그레이드 시 0으로 초기화됨 → 초기값 설정이 필요하면 `GetGovContractsTransition()`의 StateParam 로직 확장이 필요 (L4)

### 컨트랙트 삭제

- 체인에 이미 배포된 컨트랙트는 "삭제"가 불가능 (주소는 영구 존재)
- 실무적으로는 "사용 중단(deprecate)" 패턴:
  1. Go 측 `GovContracts` 구조체에서 해당 필드를 optional(`*GovContract`)로 유지하거나 no-op 구현으로 교체
  2. 다음 하드포크에서 해당 주소를 빈 컨트랙트로 덮어쓰기
- 소스만 제거하고 Go 타입을 그대로 두면 **nil deref 버그** 발생 가능

## solc 버전 / OpenZeppelin 경로

- **solc 버전**: `0.8.14` (하드코딩, `wemixgov/governance-contract/compiler.go:37`)
- **자동 다운로드**: `solcdownloader.GetSolcBin(solcVersion)` — 로컬에 없으면 다운로드
- **최적화**: `--optimize` 항상 켜짐
- **OpenZeppelin remapping**:
  - `@openzeppelin/contracts/` → `{root}/openzeppelin/contracts/contracts/`
  - `@openzeppelin/contracts-upgradeable/` → `{root}/openzeppelin/contracts-upgradeable/contracts/`
- **allow-paths**: `.,./,../` (상위 디렉터리 참조 허용)

solc 버전을 올리려면 `compiler.go:37`의 `solcVersion` 변수와 Solidity pragma를 함께 바꾸고 모든 컨트랙트를 재컴파일해 호환성 확인.

## Solidity와 Go의 계약 (실행 계약)

- **스토리지 슬롯**: Solidity 컨트랙트의 상태 변수 선언 순서가 곧 슬롯 번호. `governance-wbft/*.go`의 `SLOT_*` 16진 상수는 이와 **1:1 대응해야 한다**.
- **주소**: `params/config_wbft.go`의 `DefaultCroissantConfig`에 하드코딩된 주소(`0x1000`~`0x1003`)와 Solidity 내부에서 다른 컨트랙트를 참조할 때 사용하는 주소가 동일해야 한다. GovStaking은 배포 시 `SLOT_GOV_CONFIG_ADDRESS`, `SLOT_GOV_REWARDEE_IMP_ADDRESS` 슬롯을 통해 다른 컨트랙트 주소를 주입받는 구조.
- **BLS PoP 프리컴파일**: GovStaking 배포 시 `SLOT_BLS_POP_PRECOMPILED_ADDRESS`(`0x0`)에 `params.BLSPoPPrecompileAddress` 주입 — Solidity 코드에서 이 슬롯을 읽도록 구현해야 한다.

## 다음 단계

- 빌드 및 바이트코드 아티팩트 생성 → [02-build-compile.md](02-build-compile.md)
- Go 바인딩(스토리지 상수/state reader) 갱신 → [03-go-bindings.md](03-go-bindings.md)
