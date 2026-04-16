# go-wbft

go-ethereum(geth) 포크 기반 WEMIX 블록체인 클라이언트 — go-wemix(PoA)에서 WBFT(DPoS+BFT) 합의로 전환하는 하드포크 프로젝트.

## 빌드

```bash
make gwemix             # 메인 클라이언트 빌드
make genesis_generator  # 제네시스 생성 도구 빌드
make all                # 전체 13개 바이너리 빌드
make test               # 테스트 실행
make lint               # 린터 실행
```

## 프로젝트 구조

- 빌드 참여: 165개 패키지, 791개 Go 파일 (상세: `.claude/docs/build-source-files.md`)
- 메인 클라이언트: `cmd/gwemix/`
- 합의 엔진: WBFT (`consensus/wbft/`) — QBFT 기반 BFT 합의
- 거버넌스: `wemixgov/` — 거버넌스 컨트랙트 (GovConfig, GovStaking, GovRewardee, GovNCP)
- 솔리디티 컨트랙트: `wemixgov/governance-contract/contracts-wbft/` (WBFT용)
- 이전 버전 컨트랙트: `wemixgov/governance-contract/contracts/` (go-wemix용)

## go-wbft 고유 코드 (geth에 없는 것)

핵심 패키지:
- `consensus/wbft/` — WBFT 합의 엔진 전체 (7개 하위 패키지)
- `consensus/wpoa/` — go-wemix PoA 합의 (하드포크 이전 블록 처리)
- `consensus/wemix/` — WEMIX 합의 공통 인터페이스
- `wemixgov/` — 거버넌스 컨트랙트 (GovConfig, GovStaking, GovRewardee, GovNCP)
- `wemixgov/governance-wbft/` — WBFT 거버넌스 Go 구현
- `cmd/gwemix/` — WEMIX 메인 클라이언트
- `cmd/genesis_generator/` — 제네시스 블록 생성기
- `cmd/db_migrator/` — DB 마이그레이션 도구

기존 패키지 내 고유 파일:
- `core/wemix_genesis.go` — WEMIX 제네시스 설정
- `core/types/istanbul.go` — WBFT 블록 헤더 타입 (WBFTExtra, EpochInfo, SealerSet)
- `params/config_wbft.go` — WBFT 체인 설정 (CroissantConfig, WBFTConfig, GovContracts)
- `eth/handler_istanbul.go` — WBFT 메시지 핸들러
- `eth/quorum_protocol.go` — Quorum 프로토콜 통합
- `eth/api_wemix.go` — WEMIX RPC API (Brioche halving, 블록 리워드)

## 하드포크 히스토리

Pangyo → Applepie → **Brioche** (halving 적용) → **Croissant** (WBFT 합의 활성화)

- Croissant: WBFT 합의 전환 블록 — `CroissantBlock`, `CroissantConfig` (WBFT + Init + GovContracts)
- Brioche: 블록 리워드 halving — `BriocheBlock`, `BriocheConfig`

## 핵심 용어

| 용어 | 의미 |
|------|------|
| Croissant | WBFT 합의가 활성화되는 하드포크 |
| wemixgov | 거버넌스 시스템 (go-stablenet의 systemcontracts에 해당) |
| GovConfig (0x1000) | 스테이킹 파라미터 설정 컨트랙트 |
| GovStaking (0x1001) | 스테이킹 관리 컨트랙트 |
| GovRewardeeImp (0x1002) | 블록 리워드 분배 컨트랙트 |
| GovNCP (0x1003) | NCP(Network Council Point) 관리 컨트랙트 |
| wpoa | go-wemix에서 사용하던 PoA 합의 (Croissant 이전) |

## 코드 컨벤션

코드 작성/수정 시 `.claude/docs/code-convention.md`의 규칙을 준수할 것.

## 코드 분석 시 주의사항

- `.claude/docs/build-source-files.md`에 나열된 파일만 실제 바이너리에 포함됨
- go-wbft 고유 코드와 geth 원본 코드를 구분할 것
- `wemixgov/`는 go-stablenet의 `systemcontracts/`에 해당하는 역할 — 용어를 혼동하지 말 것
- 코드 검토 시 `/wbft-review-code` 명령어 사용 가능
