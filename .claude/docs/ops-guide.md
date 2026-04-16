# go-wbft 운영 가이드 (§19-§20)

> 제네시스 생성, 주요 설정값, 주의사항.

---

## 19. 제네시스 생성

### 도구

```bash
make genesis_generator  # 빌드
build/bin/genesis_generator [options]
```

### 제네시스 JSON 필수 필드

CroissantConfig가 포함된 제네시스:

```json
{
  "config": {
    "croissantBlock": 0,
    "croissant": {
      "wBFT": {
        "requestTimeoutSeconds": 2,
        "blockPeriodSeconds": 1,
        "epochLength": 10,
        "blockReward": "0xde0b6b3a7640000",
        "targetValidators": 1,
        "stabilizingStakersThreshold": 1
      },
      "init": {
        "validators": ["0x..."],
        "blsPublicKeys": ["0x..."]
      },
      "govContracts": {
        "govConfig": {
          "address": "0x1000",
          "version": "v1",
          "params": {
            "minimumStaking": "10000000000000000000000000",
            "maximumStaking": "100000000000000000000000000",
            "unbondingPeriodStaker": "604800",
            "unbondingPeriodDelegator": "259200",
            "feePrecision": "10000",
            "changeFeeDelay": "604800"
          }
        },
        "govStaking": {
          "address": "0x1001",
          "version": "v1"
        },
        "govRewardeeImp": {
          "address": "0x1002",
          "version": "v1"
        }
      }
    }
  }
}
```

### 검증 규칙 (CroissantConfig.CheckValidity)

- `init.validators`와 `init.blsPublicKeys` 길이 일치 필수
- `wBFT.requestTimeoutSeconds > 0`
- `wBFT.blockPeriodSeconds > 0`
- `wBFT.epochLength >= 2`
- `wBFT.epochLength >= targetValidators`
- `wBFT.stabilizingStakersThreshold > 0`
- `govContracts.govConfig` 필수
- `govContracts.govStaking` 필수
- `govContracts.govRewardeeImp` 필수
- BlockRewardBeneficiary 총 numerator ≤ denominator

---

## 20. 주요 설정값

### WBFT 합의 파라미터

| 설정 | 기본값 | 단위 | 설명 |
|------|--------|------|------|
| RequestTimeoutSeconds | 2 | 초 | 합의 라운드 타임아웃 |
| BlockPeriodSeconds | 1 | 초 | 블록 간 최소 시간 |
| EpochLength | 10 | 블록 | 밸리데이터 셋 유지 기간 |
| BlockReward | 1 WEMIX | wei | 블록 리워드 |
| TargetValidators | 1 | 개수 | 목표 밸리데이터 수 |
| MaxRequestTimeoutSeconds | - | 초 | 최대 라운드 타임아웃 |
| StabilizingStakersThreshold | 1 | 개수 | 안정화 모드 스테이커 임계값 |
| ProposerPolicy | 0 | - | 0=RoundRobin, 1=Sticky |
| UseNCP | false | - | NCP 사용 여부 |

### 거버넌스 컨트랙트 파라미터

| 설정 | 기본값 | 설명 |
|------|--------|------|
| minimumStaking | 10M WEMIX | 최소 스테이킹 |
| maximumStaking | 100M WEMIX | 최대 스테이킹 |
| unbondingPeriodStaker | 604800 (7일) | 스테이커 언본딩 |
| unbondingPeriodDelegator | 259200 (3일) | 위임자 언본딩 |
| feePrecision | 10000 | 수수료 정밀도 (0.01%) |
| changeFeeDelay | 604800 (7일) | 수수료 변경 지연 |

### Diligence 파라미터

| 설정 | 값 | 설명 |
|------|-----|------|
| DiligenceDenominator | 1,000,000 | 정밀도 단위 |
| DefaultDiligence | 1,900,000 | 최대값의 95% |
| 최대 Diligence | 2,000,000 | 2 × Denominator |

---

## 주의사항 요약

### 빌드

- [ ] `make gwemix` 빌드 성공 확인
- [ ] `make test` 전체 테스트 통과 확인
- [ ] `make lint` 린트 통과 확인

### 합의 관련

- [ ] WBFTExtra의 `IstanbulExtraVanity`는 32바이트 고정 — 변경 금지
- [ ] BLS 서명은 96바이트
- [ ] `EpochInfo`는 에폭 마지막 블록에만 존재
- [ ] `Validators`는 주소가 아닌 스테이커 인덱스 배열
- [ ] `ErrStoppedEngine`은 동기화 중 정상 — 에러가 아님

### 거버넌스 관련

- [ ] `wemixgov/bind/` 파일은 자동 생성 — 수동 편집 금지
- [ ] `wemixgov/governance-wbft/govcontracts/` 바이트코드는 Solidity 컴파일 결과 — 수동 편집 금지
- [ ] 컨트랙트 버전은 단조 증가 (v1 → v2)
- [ ] GovConfig 스토리지 슬롯 매핑 변경 시 governance.go도 업데이트 필요

### 코드 수정

- [ ] `core/types/istanbul.go` 수정 시 RLP 인코딩/디코딩 호환성 확인
- [ ] `params/config_wbft.go` 수정 시 JSON 마샬링/언마샬링 확인
- [ ] 새 하드포크 추가 시 `CheckValidity()` 검증 로직 업데이트
- [ ] Transition/Upgrade 추가 시 블록 번호 단조 증가 확인

### go-wemix vs go-wbft 구분

- [ ] `systemcontracts` 용어 사용하지 말 것 — go-wbft에서는 `wemixgov`
- [ ] `gstable` 사용하지 말 것 — go-wbft에서는 `gwemix`
- [ ] Croissant 이전 블록은 wpoa 합의 — WBFT 로직 적용하지 말 것
