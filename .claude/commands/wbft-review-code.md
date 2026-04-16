---
description: "go-wbft 코드 분석 및 질의응답. 코드 구조, 동작 흐름, 영향도 분석, 수정 제안 등을 수행한다."
---

# go-wbft 코드 리뷰

## 규칙
1. 빌드 범위 내 코드만 분석 대상: `.claude/docs/build-source-files.md` 참조
2. go-wbft 고유 코드와 geth 원본 코드를 구분할 것
3. 추측 금지 — Read/Grep으로 실제 코드를 확인 후 답변
4. 효율적 도구 사용:
   - 같은 심볼을 같은 패턴으로 반복 Grep하지 않는다 (결과를 기억하고 재사용)
   - 독립적인 Read/Grep은 병렬로 호출한다
   - 충분한 정보가 확보되면 즉시 답변으로 이동한다
5. **문서는 아래 인덱스를 보고 관련 섹션만 Read(offset/limit)로 로드** — 전체 파일을 읽지 말 것

## 접근 순서
1. 질문을 `.claude/docs/review-guide.md`의 10가지 유형 중 하나에 매칭한다
2. 매칭된 유형의 탐색 방법(Grep → Read 순서, 추적 홉 수 등)을 따른다
3. 문서 참조가 필요하면 아래 인덱스에서 키워드로 찾아 해당 섹션만 로드한다
4. 확신이 없으면 가장 유사한 유형 2개의 탐색 방법을 병합한다
5. 답변에 충분한 정보가 모이면 즉시 응답한다 — 추가 확인이 필요한 부분은 명시한다

## go-wbft 고유 코드 식별
- geth 원본에 없는 go-wbft 전용 패키지 및 파일의 **전체 목록**은 `.claude/docs/review-guide.md`의 "go-wbft 고유 코드 맵" 참조
- 핵심 패키지: `consensus/wbft/`, `consensus/wpoa/`, `wemixgov/`, `cmd/gwemix/`, `cmd/genesis_generator/`
- 주의: go-stablenet의 `systemcontracts/`는 go-wbft에서 `wemixgov/`에 해당

## 문서 인덱스 (필요 시에만 해당 파일/섹션을 로드)

키워드를 매칭하여 해당 파일을 Read한다. 파일이 주제별로 분할되어 있으므로 파일 전체를 읽거나, 큰 파일은 Grep으로 헤딩을 찾아 해당 구간만 Read한다.

### 기본 참조

| 토픽 | 키워드 | 파일 |
|------|--------|------|
| 빌드 파일 목록 | 빌드 대상, 파일 목록 | `.claude/docs/build-source-files.md` |
| 질문별 탐색 가이드 | 탐색 가이드, 응답 형식 | `.claude/docs/review-guide.md` |
| 코드 컨벤션 | 네이밍, import, error, solidity, commit | `.claude/docs/code-convention.md` |

### dev-basics — 빌드/아키텍처/테스트 (`.claude/docs/dev-basics.md`)

| 토픽 | 키워드 | 헤딩 |
|------|--------|------|
| 프로젝트 개요 | chain id, 블록 주기, 개요, 하드포크 | `## 1. 프로젝트 개요` |
| 빌드 시스템 | make, build, 빌드, 컴파일 | `## 2. 빌드 시스템` |
| 코드 생성 파일 | codegen, gen_*, protobuf | `## 3. 코드 생성 파일` |
| 아키텍처 & 패키지 | architecture, 패키지 구조, 의존성 | `## 4. 아키텍처` |
| 핵심 인터페이스 | interface, Backend, Engine, consensus | `## 5. 핵심 인터페이스` |
| 테스트 | test, 테스트, coverage | `## 6. 테스트` |
| 린팅 & 포맷팅 | lint, format, golangci | `## 7. 린팅` |

### wbft-features — go-wbft 고유 기능 (`.claude/docs/wbft-features.md`)

| 토픽 | 키워드 | 헤딩 |
|------|--------|------|
| 거버넌스 컨트랙트 | governance, wemixgov, 거버넌스, GovConfig, GovStaking | `## 8. 거버넌스 컨트랙트` |
| 하드포크 히스토리 | hardfork, 하드포크, Croissant, Brioche, fork | `## 9. 하드포크 히스토리` |
| Fee Delegation | fee delegation, 수수료 위임, FeePayer | `## 10. Fee Delegation` |
| Brioche Halving | halving, 반감기, 블록 리워드 | `## 11. Brioche Halving` |
| 솔리디티 컨트랙트 | solidity, contracts-wbft, contracts, 컨트랙트 소스 | `## 12. 솔리디티 컨트랙트` |
| 이전 합의 (wpoa) | wpoa, go-wemix, PoA, NCP, 이전 합의 | `## 13. 이전 합의 (wpoa)` |

### wbft-consensus — 합의 엔진 (`.claude/docs/wbft-consensus.md`)

| 토픽 | 키워드 | 헤딩 |
|------|--------|------|
| WBFT 합의 엔진 | wbft, 합의, consensus, BFT, 라운드 | `## 14. WBFT 합의 엔진` |
| WBFT Extra 포맷 | extra, header extra, 헤더, EpochInfo, SealerSet | `## 15. WBFT 블록 헤더 Extra` |
| WBFT RPC API | rpc, api, istanbul_*, GetWbftExtraInfo | `## 16. WBFT 커스텀 RPC` |
| Istanbul P2P | p2p, istanbul, 네트워크 메시지 | `## 17. Istanbul P2P` |
| Epoch & Validator | epoch, validator, staker, diligence | `## 18. Epoch 및 Validator 관리` |

### governance-flow — 거버넌스 컨트랙트 상세 흐름 (`.claude/docs/governance-flow.md`)

| 토픽 | 키워드 | 헤딩 |
|------|--------|------|
| 핵심 데이터 구조 | ChainConfig, CroissantConfig, GovContracts, Upgrade | `## 1. 핵심 데이터 구조` |
| 제네시스 초기화 | genesis, InjectContracts, alloc, Block 0 | `## 2. 제네시스 초기화` |
| 런타임 업그레이드 | runtime, Finalize, StateTransition, Block N | `## 3. 런타임 업그레이드` |
| 컨트랙트 버저닝 | version, v1/v2, upgrade, 바이트코드 | `## 4. 컨트랙트 버저닝` |
| 새 하드포크 추가 가이드 | 새 하드포크, GovContractUpgrades, 단계별 | `## 5. 새 하드포크 추가` |
| 파일 참조표 | 파일 역할, 파일 참조 | `## 6. 파일 참조표` |

### ops-guide — 운영 (`.claude/docs/ops-guide.md`)

| 토픽 | 키워드 | 헤딩 |
|------|--------|------|
| 제네시스 생성 | genesis 생성, genesis_generator | `## 19. 제네시스 생성` |
| 주요 설정값 | 설정값, 파라미터, 임계값, 에폭, 스테이킹 | `## 20. 주요 설정값` |
| 주의사항 요약 | 금지, 필수, 주의, 체크리스트 | `## 주의사항 요약` |

$ARGUMENTS
