# go-wbft 빌드 소스 파일 참조 (§1-§5)

> 실제 바이너리에 포함되는 패키지와 파일 목록. `go list -deps`로 추출.

---

## 1. 빌드 요약

| 항목 | 값 |
|------|-----|
| 바이너리 수 | 13개 |
| 내부 패키지 수 | 165개 |
| Go 소스 파일 수 | 791개 |

---

## 2. 바이너리 목록

| 바이너리 | 역할 |
|----------|------|
| `gwemix` | 메인 노드 클라이언트 |
| `genesis_generator` | 제네시스 파일 생성 도구 |
| `abigen` | 컨트랙트 ABI 코드 생성기 |
| `abidump` | ABI 덤프 도구 |
| `bootnode` | P2P 부트스트랩 노드 |
| `clef` | 계정 서명 도구 |
| `db_migrator` | 데이터베이스 마이그레이션 |
| `devp2p` | P2P 프로토콜 도구 |
| `era` | ERA 포맷 도구 |
| `ethkey` | 키 관리 도구 |
| `evm` | EVM 바이트코드 실행기 |
| `p2psim` | P2P 시뮬레이터 |
| `rlpdump` | RLP 데이터 검사 도구 |

---

## 3. 패키지 목록 (카테고리별)

### root (1 패키지, 1 파일)

| 패키지 | 파일 수 |
|--------|---------|
| `github.com/ethereum/go-ethereum` | 1 |

### accounts (6 패키지, 30 파일)

| 패키지 | 파일 수 |
|--------|---------|
| `accounts` | 6 |
| `accounts/abi` | 14 |
| `accounts/abi/bind` | 6 |
| `accounts/external` | 1 |
| `accounts/keystore` | 9 |
| `accounts/scwallet` | 4 |
| `accounts/usbwallet` | 4 |
| `accounts/usbwallet/trezor` | 5 |

### beacon (1 패키지, 5 파일)

| 패키지 | 파일 수 |
|--------|---------|
| `beacon/engine` | 5 |

### cmd (16 패키지, 56 파일)

| 패키지 | 파일 수 |
|--------|---------|
| `cmd/gwemix` | 10 |
| `cmd/genesis_generator` | 3 |
| `cmd/abidump` | 1 |
| `cmd/abigen` | 2 |
| `cmd/bootnode` | 1 |
| `cmd/clef` | 1 |
| `cmd/db_migrator` | 1 |
| `cmd/devp2p` | 13 |
| `cmd/devp2p/internal/ethtest` | 7 |
| `cmd/devp2p/internal/v4test` | 2 |
| `cmd/devp2p/internal/v5test` | 2 |
| `cmd/era` | 1 |
| `cmd/ethkey` | 6 |
| `cmd/evm` | 6 |
| `cmd/evm/internal/compiler` | 1 |
| `cmd/evm/internal/t8ntool` | 10 |
| `cmd/p2psim` | 1 |
| `cmd/rlpdump` | 1 |
| `cmd/utils` | 5 |

### common (7 패키지, 24 파일)

| 패키지 | 파일 수 |
|--------|---------|
| `common` | 8 |
| `common/bitutil` | 2 |
| `common/compiler` | 2 |
| `common/fdlimit` | 1 |
| `common/hexutil` | 2 |
| `common/lru` | 3 |
| `common/math` | 2 |
| `common/mclock` | 3 |
| `common/prque` | 3 |

### consensus (13 패키지, 39 파일) ★

| 패키지 | 파일 수 | go-wbft 고유 |
|--------|---------|-------------|
| `consensus` | 3 | |
| `consensus/beacon` | 2 | |
| `consensus/clique` | 3 | |
| `consensus/ethash` | 3 | |
| `consensus/misc` | 2 | |
| `consensus/misc/eip1559` | 1 | |
| `consensus/misc/eip4844` | 1 | |
| **`consensus/wbft`** | **5** | **★ WBFT 합의** |
| **`consensus/wbft/backend`** | **4** | **★** |
| **`consensus/wbft/common`** | **2** | **★** |
| **`consensus/wbft/core`** | **17** | **★** |
| **`consensus/wbft/engine`** | **2** | **★** |
| **`consensus/wbft/messages`** | **7** | **★** |
| **`consensus/wbft/validator`** | **2** | **★** |
| **`consensus/wemix`** | **1** | **★** |
| **`consensus/wpoa`** | **6** | **★** |

### core (18 패키지, 155 파일)

| 패키지 | 파일 수 |
|--------|---------|
| `core` | 24 |
| `core/asm` | 4 |
| `core/bloombits` | 4 |
| `core/forkid` | 1 |
| `core/rawdb` | 21 |
| `core/state` | 11 |
| `core/state/pruner` | 2 |
| `core/state/snapshot` | 13 |
| `core/txpool` | 5 |
| `core/txpool/blobpool` | 8 |
| `core/txpool/legacypool` | 4 |
| `core/types` | 30 |
| `core/vm` | 22 |
| `core/vm/runtime` | 3 |

### crypto (10 패키지, 53 파일)

| 패키지 | 파일 수 |
|--------|---------|
| `crypto` | 2 |
| `crypto/blake2b` | 5 |
| `crypto/bls` | 4 |
| `crypto/bls/blst` | 6 |
| `crypto/bls/common` | 3 |
| `crypto/bls12381` | 14 |
| `crypto/bn256` | 1 |
| `crypto/bn256/cloudflare` | 11 |
| `crypto/ecies` | 2 |
| `crypto/kzg4844` | 3 |
| `crypto/secp256k1` | 1 |
| `crypto/secp256r1` | 1 |

### eth (16 패키지, 90 파일)

| 패키지 | 파일 수 |
|--------|---------|
| `eth` | 17 |
| `eth/catalyst` | 5 |
| `eth/downloader` | 17 |
| `eth/ethconfig` | 2 |
| `eth/fetcher` | 2 |
| `eth/filters` | 3 |
| `eth/gasestimator` | 1 |
| `eth/gasprice` | 2 |
| `eth/protocols/eth` | 11 |
| `eth/protocols/snap` | 9 |
| `eth/tracers` | 3 |
| `eth/tracers/js` | 2 |
| `eth/tracers/js/internal/tracers` | 1 |
| `eth/tracers/logger` | 4 |
| `eth/tracers/native` | 10 |

### ethclient~event (4 패키지, 16 파일)

| 패키지 | 파일 수 |
|--------|---------|
| `ethclient` | 2 |
| `ethdb` | 4 |
| `ethdb/leveldb` | 1 |
| `ethdb/memorydb` | 1 |
| `ethdb/pebble` | 1 |
| `ethdb/remotedb` | 1 |
| `ethstats` | 1 |
| `event` | 5 |

### graphql (2 패키지, 5 파일)

| 패키지 | 파일 수 |
|--------|---------|
| `graphql` | 4 |
| `graphql/internal/graphiql` | 1 |

### internal (12 패키지, 28 파일)

| 패키지 | 파일 수 |
|--------|---------|
| `internal/debug` | 4 |
| `internal/era` | 4 |
| `internal/era/e2store` | 1 |
| `internal/ethapi` | 6 |
| `internal/flags` | 3 |
| `internal/jsre` | 3 |
| `internal/jsre/deps` | 1 |
| `internal/reexec` | 2 |
| `internal/shutdowncheck` | 1 |
| `internal/syncx` | 1 |
| `internal/utesting` | 1 |
| `internal/version` | 2 |
| `internal/web3ext` | 1 |

### infra (19 패키지, 86 파일)

| 패키지 | 파일 수 |
|--------|---------|
| `log` | 5 |
| `metrics` | 28 |
| `metrics/exp` | 1 |
| `metrics/influxdb` | 3 |
| `metrics/prometheus` | 2 |
| `miner` | 5 |
| `node` | 11 |
| `rlp` | 8 |
| `rlp/internal/rlpstruct` | 1 |
| `rpc` | 19 |

### p2p (13 패키지, 60 파일)

| 패키지 | 파일 수 |
|--------|---------|
| `p2p` | 10 |
| `p2p/discover` | 9 |
| `p2p/discover/v4wire` | 1 |
| `p2p/discover/v5wire` | 4 |
| `p2p/dnsdisc` | 5 |
| `p2p/enode` | 6 |
| `p2p/enr` | 2 |
| `p2p/msgrate` | 1 |
| `p2p/nat` | 3 |
| `p2p/netutil` | 5 |
| `p2p/rlpx` | 2 |
| `p2p/simulations` | 7 |
| `p2p/simulations/adapters` | 3 |
| `p2p/simulations/pipes` | 1 |
| `p2p/tracker` | 1 |

### params (2 패키지, 9 파일)

| 패키지 | 파일 수 |
|--------|---------|
| `params` | 8 |
| `params/forks` | 1 |

### signer (4 패키지, 12 파일)

| 패키지 | 파일 수 |
|--------|---------|
| `signer/core` | 8 |
| `signer/core/apitypes` | 1 |
| `signer/fourbyte` | 3 |
| `signer/rules` | 1 |
| `signer/storage` | 2 |

### trie (5 패키지, 22 파일)

| 패키지 | 파일 수 |
|--------|---------|
| `trie` | 16 |
| `trie/trienode` | 2 |
| `trie/triestate` | 1 |
| `trie/utils` | 1 |
| `triedb` | 2 |
| `triedb/database` | 1 |
| `triedb/hashdb` | 1 |
| `triedb/pathdb` | 10 |

### wemixgov (4 패키지, 15 파일) ★

| 패키지 | 파일 수 | go-wbft 고유 |
|--------|---------|-------------|
| **`wemixgov`** | **1** | **★ 거버넌스 API** |
| **`wemixgov/bind`** | **8** | **★ ABI 바인딩 (자동 생성)** |
| **`wemixgov/cli`** | **1** | **★ CLI** |
| **`wemixgov/governance-wbft`** | **5** | **★ WBFT 거버넌스 구현** |

### tests (1 패키지, 11 파일)

| 패키지 | 파일 수 |
|--------|---------|
| `tests` | 11 |

### console (2 패키지, 3 파일)

| 패키지 | 파일 수 |
|--------|---------|
| `console` | 2 |
| `console/prompt` | 1 |

---

## 4. 카테고리별 집계

| 카테고리 | 패키지 수 | 파일 수 | go-wbft 고유 |
|----------|-----------|---------|-------------|
| root | 1 | 1 | |
| accounts | 8 | 49 | |
| beacon | 1 | 5 | |
| **cmd** | **19** | **73** | **★ gwemix, genesis_generator, db_migrator** |
| common | 9 | 26 | |
| **consensus** | **16** | **52** | **★ wbft(39), wpoa(6), wemix(1)** |
| core | 14 | 155 | |
| crypto | 12 | 53 | |
| eth | 15 | 90 | |
| ethclient~event | 8 | 16 | |
| graphql | 2 | 5 | |
| internal | 13 | 30 | |
| infra | 10 | 83 | |
| p2p | 15 | 60 | |
| params | 2 | 9 | |
| signer | 5 | 15 | |
| trie/triedb | 8 | 34 | |
| **wemixgov** | **4** | **15** | **★ 거버넌스 전체** |
| tests | 1 | 11 | |
| console | 2 | 3 | |
| **합계** | **165** | **791** | |

---

## 5. go-wbft 고유 코드 요약

### 전용 패키지 (14개)

- `consensus/wbft/` (7개 하위 패키지) — 39파일
- `consensus/wpoa/` — 6파일
- `consensus/wemix/` — 1파일
- `wemixgov/` (4개 패키지) — 15파일
- `cmd/gwemix/` — 10파일
- `cmd/genesis_generator/` — 3파일
- `cmd/db_migrator/` — 1파일

### 기존 패키지 내 고유 파일 (6개)

- `core/wemix_genesis.go`
- `core/types/istanbul.go`
- `params/config_wbft.go`
- `eth/handler_istanbul.go`
- `eth/quorum_protocol.go`
- `eth/api_wemix.go`

### 주의사항

- 플랫폼(OS/arch)에 따라 일부 파일이 다를 수 있음
- 서드파티 의존성(`vendor/`, `go.sum`)은 제외
- 테스트 파일(`*_test.go`)은 제외
- 빌드 도구(`build/ci.go`, `compile/`)는 제외
- `wemixgov/bind/`의 ABI 바인딩 파일은 자동 생성 — 수동 편집 금지
