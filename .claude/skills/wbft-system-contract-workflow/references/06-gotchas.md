# 불변식 · 자주 하는 실수 · 테스트 가이드

## 목차
- 핵심 불변식 (깨뜨리면 합의 불일치)
- 자주 하는 실수
- 버전 업그레이드 스토리지 레이아웃
- 삭제 시 주의
- 테스트 패턴
- 디버깅 힌트

## 핵심 불변식

### INV-1: 단일 수렴점
**모든 컨트랙트 배포/초기화는 `GetGovContractsTransition()`을 통과**한다. 제네시스와 런타임 업그레이드 경로가 동일한 함수를 호출하므로, 이 함수에만 로직을 추가하면 두 경로에 자동 반영된다.

- **반례**: 제네시스용 로직을 `InjectContracts`에 직접 추가하면 런타임 업그레이드 경로에서 누락 → 동일 블록에서 노드마다 다른 state → **합의 불일치**

### INV-2: 결정론적 빌드
`wemixgov/governance-contract/compiler.go`는 solc 0.8.14 + `--optimize`로 고정. 다른 버전/옵션으로 빌드된 바이트코드는 다른 bytecode hash를 생성 → 검증 실패.

- **반례**: 로컬 환경에서 solc 0.8.15로 빌드 후 커밋 → 타 노드와 bytecode mismatch
- **대응**: CI에서 `compile.go` 재실행 후 diff 없음을 확인

### INV-3: 스토리지 레이아웃 호환성
버전 업그레이드 시 **기존 상태변수 선언 순서/타입 불변**. 새 변수는 끝에만 추가.

- **반례**: v1 `GovStaking.sol`의 `uint256 totalStaking` 앞에 새 변수 삽입 → 슬롯 번호 shift → Go 측 `SLOT_TOTAL_STAKING`이 잘못된 값을 읽음 → 블록 리워드 계산 오류

### INV-4: 주소 영역 예약
- `0x1000`: GovConfig (고정)
- `0x1001`: GovStaking (고정)
- `0x1002`: GovRewardeeImp (고정)
- `0x1003`: GovNCP (고정, optional)
- `0x1004+`: 새 컨트랙트용

주소는 한 번 정해지면 변경 불가 (이미 배포된 state가 그 주소에 있으므로).

### INV-5: BLS PoP 프리컴파일 주소 주입
GovStaking 배포 시 `SLOT_BLS_POP_PRECOMPILED_ADDRESS`(0x0)에 `params.BLSPoPPrecompileAddress`를 항상 주입해야 한다 (`governance.go:88-89`).

- **반례**: v2 GovStaking에서 이 슬롯을 다른 용도로 재사용 → BLS PoP 검증 실패 → 합의 실패

### INV-6: NCP 초기화 필수
`GovNCP`가 non-nil이면 `ncps` 파라미터에 최소 하나의 주소가 있어야 한다 (`governance.go:111`). 비어 있으면 에러 반환.

### INV-7: Upgrade 블록 정확 일치
`GetGovContractsStateTransition`은 `num.Cmp(upgrade.Block) == 0`일 때만 적용 — **오름차순 정렬**된 `GovContractUpgrades`를 가정하며, 한 블록에 여러 업그레이드 금지.

- **반례**: 같은 블록 번호에 두 Upgrade 항목 → 첫 번째만 매칭되고 두 번째는 누락

## 자주 하는 실수

| 실수 | 증상 | 해결 |
|------|------|------|
| solc 버전 변경 후 `compile.go` 미실행 | 빌드 성공하지만 노드 간 bytecode mismatch | `compile.go` 재실행 + git diff 확인 |
| `contracts.go`의 `//go:embed` 경로 오타 | Go 빌드 에러 (`pattern X: no matching files`) | 파일명이 `CONTRACT_*` 상수와 정확히 일치해야 함 |
| `init()` 맵 등록 누락 | `checkGovContractVersions`에서 "unsupported version" | `GovContractCodes[CONTRACT_X][VERSION_Y]` 등록 확인 |
| `GovContracts` 구조체 필드 추가 후 `GetGovContracts` 미수정 | 런타임 업그레이드에서 새 컨트랙트가 누락된 상태로 조회 | `consensus/wbft/config.go:132` 콜백 라인 추가 |
| `Upgrade` 블록 번호 비정렬 | 업그레이드 순서가 예측 불가 | 오름차순으로 정렬 후 커밋 |
| 새 컨트랙트 주소를 기존과 동일하게 지정 | 기존 컨트랙트 바이트코드 덮어씀 | 0x1004부터 새 주소 할당 |
| `SLOT_*` 상수 값이 Solidity 선언 순서와 불일치 | state reader가 잘못된 값 반환 | Solidity 상태변수를 순서대로 나열하며 0x0부터 재확인 |
| 런타임 Upgrade에서 스토리지 리셋 기대 | 기존 스토리지가 보존되어 stale data 사용 | `Upgrade.GovContracts`의 `Params`에 재초기화 값 명시, `GetGovContractsTransition`에서 StateParam으로 덮어쓰기 |

## 버전 업그레이드 스토리지 레이아웃

### 안전한 변경
- ✅ 새 상태변수를 **맨 뒤에 추가**
- ✅ 함수 추가 (시그니처 무관)
- ✅ 함수 내부 로직 변경
- ✅ 이벤트 추가

### 위험한 변경 (합의 불일치 가능)
- ❌ 기존 상태변수 순서 변경
- ❌ 기존 상태변수 타입 변경 (`uint256` → `address` 등)
- ❌ 기존 상태변수 제거
- ❌ Solidity 구조체 내부 필드 순서 변경 (packed layout 깨짐)
- ❌ `mapping`의 key/value 타입 변경

### 회색 지대
- ⚠️ `public` 상태변수를 `private`으로 변경: ABI는 바뀌지만 슬롯은 유지. Go 측 state reader는 영향 없음. 단, 외부 Solidity 호출자가 있으면 깨짐.
- ⚠️ 이전에 제거된 슬롯을 재사용: 0으로 초기화되어 있다고 가정하기 쉽지만, 기존 값이 남아 있을 수 있음. 업그레이드 시 명시적으로 0으로 재초기화 필요.

## 삭제 시 주의

컨트랙트 "삭제"는 블록체인에서 **논리적 개념**일 뿐 주소는 영구 존재한다.

### 안전한 deprecate 패턴

1. Go 구조체 필드는 **optional(`*GovContract`)** 유지
2. 다음 하드포크 Upgrade에서 해당 주소를 **비어있는 컨트랙트 바이트코드**로 덮어쓰기 (`selfdestruct` 금지 — 합의 불일치)
3. 이후 블록에서 호출 시 revert되도록 처리
4. core 측 코드에서 해당 컨트랙트 조회 제거

### 하지 말 것

- ❌ Solidity 소스만 제거하고 Go 구조체 필드 그대로 둠 → 제네시스에서 nil deref
- ❌ `params.GovContracts` 구조체 필드 제거 → 기존 체인 설정 JSON 파싱 깨짐 (backward compat)
- ❌ 이미 배포된 컨트랙트를 `selfdestruct` — Cancun 이후 약화된 의미 + 기존 노드와 합의 깨짐

## 테스트 패턴

### 단위 테스트

- `wemixgov/governance-wbft/governance_test.go`: `TestGetGovContractsTransition_Full` 패턴 따라 새 컨트랙트용 케이스 추가
- 에러 경로: `TestGetGovContractsTransition_InvalidParams` 참고 (숫자 파싱 실패 등)
- NCP 유사 패턴: `TestGetGovContractsTransition_NCPEmpty` (빈 리스트 거부)

### 통합 테스트

- `consensus/wbft/engine/engine_test.go:555` 참고 — 블록 N에서 `GetGovContractsStateTransition`이 비-nil 반환하는지 확인
- 제네시스: `consensus/wbft/testutils/genesis.go:71`의 `InjectContracts` 호출 경로

### 회귀 테스트

버전 업그레이드 시 다음 시나리오를 꼭 확인:
1. v1 제네시스로 시작 → 블록 N-1까지 정상 진행
2. 블록 N에서 Upgrade 적용 (Finalize 경로)
3. v2 로직이 호출됨 (새 기능 확인)
4. v1에서 설정된 스토리지 값이 보존됨 (마이그레이션 기대하는 슬롯 제외)

## 디버깅 힌트

### "node sync fail" 또는 "bad block"
- bytecode hash mismatch 의심 → solc 버전 확인, `compile.go` 재실행
- 노드 간 `GovContractUpgrades` 설정 불일치

### "unsupported version X"
- `checkGovContractVersions` 위치 확인
- `GovContractCodes[CONTRACT_X][VERSION_Y]`가 `contracts.go:init()`에서 등록됐는지

### 제네시스 성공, 런타임 업그레이드 실패
- `Upgrade.Block` 번호 타입 (big.Int 포인터) 확인
- `processFinalize`가 해당 블록에서 호출되는지 로그 추가
- `Upgrade.GovContracts` 필드가 nil이면 스킵되는 점 인지

### state reader가 잘못된 값 반환
- `SLOT_*` 상수와 Solidity 상태변수 순서 비교
- `CalculateMappingSlot`/`CalculateDynamicSlot` 사용 시 key/index 타입 정합 (uint256 vs address)
- 매핑 내 구조체: `IncrementHash(baseSlot, fieldOffset)` 로 접근

### "Some or all of the Croissant parameters are missing"
`core/genesis.go:723` 에러 — `CroissantConfig.GovContracts` 또는 필수 하위 필드가 nil. chain config JSON 확인.

## 커밋 전 최종 체크

- [ ] `go build ./...` 성공
- [ ] `go test ./wemixgov/... ./params/... ./consensus/wbft/... ./core/...` 성공
- [ ] `make lint` 경고 없음
- [ ] `govcontracts/v*/` 바이트코드 파일이 git에 추가됨
- [ ] Solidity 소스, Go 바인딩, 체인 설정 3곳의 주소·버전·파라미터 키가 일치
- [ ] 새 테스트 케이스 추가됨
- [ ] `/wbft-review-code`로 영향도 셀프 리뷰 완료
