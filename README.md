# wbft-ai — go-wbft Claude Code 플러그인

go-wbft 프로젝트를 위한 Claude Code 커맨드 및 문서 셋.

LLM이 go-wbft 코드를 정확히 이해하고 분석할 수 있도록, 빌드에 참여하는 실제 코드만을 기반으로 정리된 참조 문서를 제공한다.

## 설치

### 로컬 설치

```bash
cd wbft-ai
chmod +x install-local.sh
./install-local.sh /path/to/go-wbft
```

### 수동 설치

1. `CLAUDE.md` → go-wbft 프로젝트 루트에 복사
2. `.claude/` → go-wbft 프로젝트 루트에 복사

## 제거

```bash
./uninstall.sh /path/to/go-wbft
```

## 사용법

```bash
cd /path/to/go-wbft
claude                           # Claude Code 실행
/wbft-review-code [질문]          # 코드 분석 커맨드
```

## 파일 구조

```
wbft-ai/
├── README.md                              # 이 파일
├── CLAUDE.md                              # 프로젝트 컨텍스트 (go-wbft 루트에 설치)
├── install-local.sh                       # 로컬 설치 스크립트
├── uninstall.sh                           # 제거 스크립트
└── .claude/
    ├── settings.local.json                # 권한 설정
    ├── commands/
    │   └── wbft-review-code.md            # 코드 분석 슬래시 커맨드
    └── docs/
        ├── review-guide.md                # 질문 유형별 탐색 가이드 + go-wbft 코드 맵
        ├── dev-basics.md                  # 빌드, 아키텍처, 인터페이스, 테스트, 린팅
        ├── wbft-consensus.md              # WBFT 합의 엔진 (상태머신, Extra, RPC, P2P, Epoch)
        ├── wbft-features.md               # go-wbft 고유 기능 (거버넌스, 하드포크, Fee Delegation, Halving)
        ├── governance-flow.md             # 거버넌스 컨트랙트 배포/업그레이드 흐름
        ├── build-source-files.md          # 빌드 참여 파일 목록 (165 패키지, 791 파일)
        ├── code-convention.md             # Go & Solidity 코드 컨벤션
        └── ops-guide.md                   # 제네시스 생성, 설정값, 주의사항
```

## 문서 설계 원칙

1. **토큰 효율성**: 문서를 주제별로 분할하여, 필요한 섹션만 로드
2. **빌드 기반**: `go list -deps`로 추출한 실제 빌드 참여 코드만 참조
3. **geth 구분**: go-wbft 고유 코드와 geth 원본 코드를 명확히 구분
4. **용어 정확성**: `systemcontracts` 대신 `wemixgov`, `gstable` 대신 `gwemix`
5. **인덱스 기반**: 커맨드에 문서 인덱스 테이블을 포함하여 키워드 기반 탐색

## 대상 프로젝트

- **go-wbft**: go-wemix(PoA)에서 WBFT(DPoS+BFT) 합의로 전환하는 하드포크 프로젝트
- **합의**: WBFT — QBFT 기반 BFT 합의, 스테이킹 기반 밸리데이터 선택
- **거버넌스**: wemixgov — GovConfig, GovStaking, GovRewardee, GovNCP 컨트랙트
- **하드포크**: Croissant — WBFT 합의가 활성화되는 하드포크
