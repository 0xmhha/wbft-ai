# go-wbft 기본 참조 (§1-§7)

> 빌드, 아키텍처, 인터페이스, 테스트, 린팅 등 개발 기본 사항.

---

## 1. 프로젝트 개요

| 항목 | 값 |
|------|-----|
| 바이너리 이름 | `gwemix` |
| Go 모듈 경로 | `github.com/ethereum/go-ethereum` |
| Go 버전 | 1.23.0 이상 (toolchain: go1.23.12) |
| 네이티브 코인 | WEMIX |
| 합의 알고리즘 (Croissant 이후) | WBFT (WEMIX Byzantine Fault Tolerance) |
| 합의 알고리즘 (Croissant 이전) | WPoA (Weighted Proof of Authority) |
| 블록 주기 | 1초 |
| 에폭 길이 (기본값) | 10블록 |
| 프로젝트 성격 | go-wemix(PoA) → go-wbft(DPoS+BFT) 하드포크 전환 |

### 하드포크 체인

```
Homestead → ... → London → Pangyo → Applepie → Brioche → Croissant(WBFT)
```

| 하드포크 | 역할 | 주요 설정 |
|----------|------|-----------|
| Pangyo | WEMIX 커스텀 포크 | `PangyoBlock` |
| Applepie | WEMIX 기능 추가 | `ApplepieBlock` |
| Brioche | 블록 리워드 halving | `BriocheBlock`, `BriocheConfig` |
| **Croissant** | **WBFT 합의 전환** | `CroissantBlock`, `CroissantConfig` |

---

## 2. 빌드 시스템

### 주요 Makefile 타겟

```bash
make gwemix             # 메인 바이너리 빌드 → build/bin/gwemix
make genesis_generator  # 제네시스 생성 도구 빌드
make all                # 전체 빌드 (13개 바이너리)
make test               # 전체 테스트 (SUCCESS_TESTS 패키지 목록 실행)
make test-short         # 빠른 테스트 (-short 플래그)
make lint               # golangci-lint 실행
make devtools           # 코드 생성 도구 설치 (stringer, gencodec, protoc, abigen, solc)
make clean              # 빌드 캐시 및 출력물 삭제
```

### 빌드 출력 위치

```
build/bin/      ← 빌드된 바이너리
build/cache/    ← 빌드 캐시 (.gitignore 포함)
build/_workspace/ ← 빌드 워크스페이스 (.gitignore 포함)
```

### 빌드 오케스트레이터

실제 빌드 로직은 `build/ci.go`에 있음. Makefile은 이 파일을 호출하는 wrapper.

---

## 3. 코드 생성 파일 (수동 편집 금지)

다음 파일들은 도구로 자동 생성되므로 **절대 직접 수정하지 말 것**.

### protobuf 생성 파일

위치: `accounts/usbwallet/trezor/`

```
messages.pb.go
messages-common.pb.go
messages-management.pb.go
messages-ethereum.pb.go
```

### gencodec 생성 파일 (JSON 마샬링)

패턴: `gen_*.go`

위치: `core/types/`, `beacon/`, `tests/`, `eth/tracers/`, `cmd/evm/`

### RLP 생성 파일

패턴: `gen_*_rlp.go`

위치: `core/types/`

### 거버넌스 컨트랙트 ABI 바인딩

위치: `wemixgov/bind/`

```
gen_gov_abi.go
gen_staking_abi.go
gen_envStorage_abi.go
gen_ballotStorage_abi.go
gen_registry_abi.go
gen_ncpExit_abi.go
```

### 거버넌스 컨트랙트 바이트코드 아티팩트

위치: `wemixgov/governance-wbft/govcontracts/v1/`, `v2/`

> **Solidity 소스 수정 후 반드시 재컴파일 필요** → `wemixgov/governance-contract/` 내 컴파일 도구 사용

---

## 4. 아키텍처 & 패키지 구조

```
cmd/gwemix/               ← 진입점 (main.go, config.go)
params/                   ← 체인 설정 (config.go, config_wbft.go)
consensus/wbft/           ← WBFT 합의 엔진
  backend/                ← 백엔드 오케스트레이션
  core/                   ← 핵심 합의 알고리즘 (preprepare, prepare, commit, roundchange)
  engine/                 ← 블록 봉인 및 제안 엔진
  messages/               ← 메시지 인코딩/디코딩
  validator/              ← 검증자 집합 관리
  common/                 ← 공용 상수/에러
consensus/wpoa/           ← go-wemix PoA 합의 (Croissant 이전 블록 처리)
consensus/wemix/          ← WEMIX 합의 공통 인터페이스
wemixgov/                 ← 거버넌스 인터페이스
  bind/                   ← ABI 바인딩 (자동 생성)
  cli/                    ← 거버넌스 CLI
  governance-wbft/        ← WBFT 거버넌스 구현 (컨트랙트 배포, 스테이킹, NCP)
  governance-contract/    ← 솔리디티 소스 코드
    contracts/            ← go-wemix용 컨트랙트 (Gov, Staking, Registry, NCPExit)
    contracts-wbft/       ← go-wbft용 컨트랙트 (GovConfig, GovStaking, GovRewardee, GovNCP)
      v1/                 ← 버전 1
      v2/                 ← 버전 2
core/vm/                  ← EVM
internal/                 ← 외부 패키지에서 import 불가
```

### 패키지 의존 규칙

- `internal/` 패키지는 이 모듈 내에서만 import 가능
- WBFT는 반드시 `consensus.Engine` 인터페이스를 구현해야 함
- 거버넌스 컨트랙트 주소는 `params.ChainConfig.Croissant.GovContracts`를 통해 접근
- go-stablenet의 `systemcontracts/`는 go-wbft에서 `wemixgov/`에 해당

---

## 5. 핵심 인터페이스

### consensus.Engine (합의 엔진이 구현해야 할 인터페이스)

파일: `consensus/consensus.go`

```go
type Engine interface {
    Author(header *types.Header) (common.Address, error)
    VerifyHeader(chain ChainHeaderReader, header *types.Header) error
    VerifyHeaders(chain ChainHeaderReader, headers []*types.Header) (chan<- struct{}, <-chan error)
    VerifyUncles(chain ChainReader, block *types.Block) error
    Prepare(chain ChainHeaderReader, header *types.Header) error
    Finalize(chain ChainHeaderReader, header *types.Header, state *state.StateDB,
             txs []*types.Transaction, uncles []*types.Header,
             withdrawals []*types.Withdrawal) error
    FinalizeAndAssemble(...) (*types.Block, error)
    Seal(chain ChainHeaderReader, block *types.Block, results chan<- *types.Block, stop <-chan struct{}) error
    SealHash(header *types.Header) common.Hash
    CalcDifficulty(chain ChainHeaderReader, time uint64, parent *types.Header) *big.Int
    APIs(chain ChainHeaderReader) []rpc.API
    Close() error
    CallEngineSpecific(method string, args ...interface{}) interface{}
}
```

### GovContractApi (거버넌스 컨트랙트 인터페이스)

파일: `wemixgov/govapi.go`

```go
type GovContractApi interface {
    GetRegistryAddress() common.Address
    GetGovAddress() common.Address
    GetStakingAddress() common.Address
    GetModifiedBlock() (*big.Int, error)
    GetBlockCreationTime() (*big.Int, error)
    GetBlockRewardAmount() (*big.Int, error)
    GetMaxPriorityFeePerGas() (*big.Int, error)
    GetMaxBaseFee() (*big.Int, error)
    GetGasLimitAndBaseFee() (*big.Int, *big.Int, *big.Int, error)
    GetNodeLength() (*big.Int, error)
    GetNode(index *big.Int) (NodeInfo, error)
    // ... 기타 거버넌스 조회 메서드
}

type GovBackend interface {
    GetGovApiWithHeight(ctx context.Context, height *big.Int) (GovContractApi, error)
}
```

---

## 6. 테스트

### 테스트 실행

```bash
make test        # 주요 패키지 전체 테스트
make test-short  # 빠른 단위 테스트
```

### 테스트 포함 패키지 (SUCCESS_TESTS)

WBFT 및 거버넌스 관련:
- `github.com/ethereum/go-ethereum/consensus/wbft/...`
- `github.com/ethereum/go-ethereum/wemixgov/...`

코어:
- `github.com/ethereum/go-ethereum/accounts`, `accounts/abi`
- `github.com/ethereum/go-ethereum/core/...`
- `github.com/ethereum/go-ethereum/crypto/...`
- `github.com/ethereum/go-ethereum/eth/...`
- `github.com/ethereum/go-ethereum/miner`
- `github.com/ethereum/go-ethereum/params`

기타:
- `cmd/gwemix`, `cmd/utils`, `cmd/abigen`, `cmd/clef`, `cmd/evm/...`, `cmd/devp2p/...`, `cmd/ethkey`, `cmd/rlpdump`
- `common/...`, `ethclient/...`, `ethdb/...`, `ethstats`, `event`, `log`, `metrics/...`
- `node`, `p2p/...`, `rlp/...`, `rpc`, `trie/...`, `triedb/...`
- `graphql/...`, `internal/...`, `signer/...`, `console`
- 총 37개 패키지 그룹

---

## 7. 린팅 & 포맷팅

### 린트 실행

```bash
make lint
```

### 활성화된 주요 린터

| 린터 | 역할 |
|------|------|
| goimports | import 순서 포맷팅 |
| govet | go vet 검사 |
| staticcheck | 정적 분석 |
| unused | 미사용 변수/함수 감지 |
| misspell | 오탈자 검출 |
| revive | 수신자 명명 규칙 |
| copyloopvar | 루프 변수 복사 문제 |

### 개발 도구 설치

```bash
make devtools
# 설치: stringer, gencodec, protoc-gen-go, abigen
# 별도 설치 필요: solc, protoc
```
