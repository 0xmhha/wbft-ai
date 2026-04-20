#!/bin/bash
# go-wbft Claude Code 플러그인 로컬 설치 스크립트
# 사용법: ./install-local.sh /path/to/go-wbft

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${1:-${GO_WBFT_DIR:-}}"

if [ -z "$TARGET_DIR" ]; then
    echo "사용법: $0 /path/to/go-wbft"
    echo "또는: GO_WBFT_DIR=/path/to/go-wbft $0"
    exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo "오류: 디렉토리가 존재하지 않습니다: $TARGET_DIR"
    exit 1
fi

echo "=== go-wbft Claude Code 플러그인 설치 ==="
echo "대상: $TARGET_DIR"
echo ""

# 기존 파일 백업
if [ -d "$TARGET_DIR/.claude" ]; then
    BACKUP_DIR="$TARGET_DIR/.claude.backup.$(date +%Y%m%d%H%M%S)"
    echo "기존 .claude/ 백업: $BACKUP_DIR"
    cp -r "$TARGET_DIR/.claude" "$BACKUP_DIR"
fi

if [ -f "$TARGET_DIR/CLAUDE.md" ]; then
    BACKUP_FILE="$TARGET_DIR/CLAUDE.md.backup.$(date +%Y%m%d%H%M%S)"
    echo "기존 CLAUDE.md 백업: $BACKUP_FILE"
    cp "$TARGET_DIR/CLAUDE.md" "$BACKUP_FILE"
fi

# 디렉토리 생성
mkdir -p "$TARGET_DIR/.claude/commands"
mkdir -p "$TARGET_DIR/.claude/docs"
mkdir -p "$TARGET_DIR/.claude/skills/wbft-system-contract-workflow/references"

# 파일 복사
echo "파일 복사 중..."

cp "$SCRIPT_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
cp "$SCRIPT_DIR/.claude/settings.local.json" "$TARGET_DIR/.claude/settings.local.json"

# 커맨드
cp "$SCRIPT_DIR/.claude/commands/wbft-review-code.md" "$TARGET_DIR/.claude/commands/wbft-review-code.md"

# 문서
for doc in review-guide.md dev-basics.md wbft-consensus.md wbft-features.md governance-flow.md build-source-files.md code-convention.md ops-guide.md; do
    cp "$SCRIPT_DIR/.claude/docs/$doc" "$TARGET_DIR/.claude/docs/$doc"
done

# 스킬: wbft-system-contract-workflow
cp "$SCRIPT_DIR/.claude/skills/wbft-system-contract-workflow/SKILL.md" \
   "$TARGET_DIR/.claude/skills/wbft-system-contract-workflow/SKILL.md"
for ref in 01-solidity-source.md 02-build-compile.md 03-go-bindings.md 04-core-integration.md 05-hardfork-recipe.md 06-gotchas.md; do
    cp "$SCRIPT_DIR/.claude/skills/wbft-system-contract-workflow/references/$ref" \
       "$TARGET_DIR/.claude/skills/wbft-system-contract-workflow/references/$ref"
done

echo ""
echo "=== 설치 완료 ==="
echo ""
echo "설치된 파일:"
echo "  $TARGET_DIR/CLAUDE.md"
echo "  $TARGET_DIR/.claude/settings.local.json"
echo "  $TARGET_DIR/.claude/commands/wbft-review-code.md"
echo "  $TARGET_DIR/.claude/docs/ (8개 문서)"
echo "  $TARGET_DIR/.claude/skills/wbft-system-contract-workflow/ (SKILL.md + references 6개)"
echo ""
echo "사용법:"
echo "  cd $TARGET_DIR"
echo "  claude  # Claude Code 실행"
echo "  /wbft-review-code [질문]  # 코드 리뷰 커맨드"
