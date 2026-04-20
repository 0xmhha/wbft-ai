#!/bin/bash
# go-wbft Claude Code 플러그인 설치 스크립트 (private repo — GitHub 인증 필요)
#
# 사용법 (gh CLI):
#   curl -fsSL -H "Authorization: token $(gh auth token)" \
#     https://raw.githubusercontent.com/0xmhha/wbft-ai/main/install.sh | bash
#
# 사용법 (GITHUB_TOKEN):
#   GITHUB_TOKEN=ghp_xxx curl -fsSL -H "Authorization: token $GITHUB_TOKEN" \
#     https://raw.githubusercontent.com/0xmhha/wbft-ai/main/install.sh | bash
#
# go-wbft 프로젝트 루트에서 실행해야 합니다.
# 또는 GO_WBFT_DIR 환경변수로 경로를 지정하세요.

set -e

REPO="0xmhha/wbft-ai"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
TARGET_DIR="${GO_WBFT_DIR:-$(pwd)}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# GitHub 토큰 해석
# 우선순위: GITHUB_TOKEN env → gh CLI
if [ -z "$GITHUB_TOKEN" ]; then
    if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
        GITHUB_TOKEN="$(gh auth token 2>/dev/null || true)"
    fi
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${RED}오류: GitHub 인증 토큰이 없습니다.${NC}"
    echo ""
    echo "다음 중 하나를 사용하세요:"
    echo ""
    echo "  # gh CLI 사용 (권장)"
    echo "  curl -fsSL -H \"Authorization: token \$(gh auth token)\" \\"
    echo "    ${BASE_URL}/install.sh | bash"
    echo ""
    echo "  # GITHUB_TOKEN 환경변수 사용"
    echo "  GITHUB_TOKEN=ghp_xxx curl -fsSL -H \"Authorization: token \$GITHUB_TOKEN\" \\"
    echo "    ${BASE_URL}/install.sh | bash"
    exit 1
fi

AUTH_HEADER="Authorization: token ${GITHUB_TOKEN}"

echo "=== go-wbft Claude Code 플러그인 설치 ==="
echo "대상 디렉토리: $TARGET_DIR"
echo ""

# go-wbft 프로젝트 루트 여부 확인
if [ ! -f "$TARGET_DIR/go.mod" ] || ! grep -q 'module github.com/ethereum/go-ethereum' "$TARGET_DIR/go.mod" 2>/dev/null; then
    echo -e "${RED}오류: go-wbft 프로젝트 루트가 아닙니다.${NC}"
    echo "go-wbft 프로젝트 루트에서 실행하거나, GO_WBFT_DIR 환경변수로 경로를 지정하세요."
    echo ""
    echo "예시:"
    echo "  GO_WBFT_DIR=/path/to/go-wbft curl -fsSL -H \"Authorization: token \$(gh auth token)\" \\"
    echo "    ${BASE_URL}/install.sh | bash"
    exit 1
fi

# 기존 파일 백업
if [ -d "$TARGET_DIR/.claude" ] || [ -f "$TARGET_DIR/CLAUDE.md" ]; then
    BACKUP_SUFFIX=$(date +%Y%m%d%H%M%S)
    echo -e "${YELLOW}기존 설정 파일 백업 중...${NC}"
    [ -d "$TARGET_DIR/.claude" ] && cp -r "$TARGET_DIR/.claude" "$TARGET_DIR/.claude.backup.$BACKUP_SUFFIX"
    [ -f "$TARGET_DIR/CLAUDE.md" ] && cp "$TARGET_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.md.backup.$BACKUP_SUFFIX"
fi

# 디렉토리 생성
mkdir -p "$TARGET_DIR/.claude/commands"
mkdir -p "$TARGET_DIR/.claude/docs"
mkdir -p "$TARGET_DIR/.claude/skills/wbft-system-contract-workflow/references"

# 파일 다운로드 함수 (GitHub 인증 헤더 포함)
download() {
    local src="$1"
    local dst="$2"
    echo "  다운로드: $src"
    curl -fsSL -H "$AUTH_HEADER" "${BASE_URL}/${src}" -o "${TARGET_DIR}/${dst}"
}

echo "파일 다운로드 중..."

# 루트 파일
download "CLAUDE.md" "CLAUDE.md"

# 커맨드
download ".claude/commands/wbft-review-code.md" ".claude/commands/wbft-review-code.md"

# 문서
for doc in review-guide.md dev-basics.md wbft-consensus.md wbft-features.md governance-flow.md build-source-files.md code-convention.md ops-guide.md; do
    download ".claude/docs/${doc}" ".claude/docs/${doc}"
done

# 스킬: wbft-system-contract-workflow
download ".claude/skills/wbft-system-contract-workflow/SKILL.md" ".claude/skills/wbft-system-contract-workflow/SKILL.md"
for ref in 01-solidity-source.md 02-build-compile.md 03-go-bindings.md 04-core-integration.md 05-hardfork-recipe.md 06-gotchas.md; do
    download ".claude/skills/wbft-system-contract-workflow/references/${ref}" ".claude/skills/wbft-system-contract-workflow/references/${ref}"
done

echo ""
echo -e "${GREEN}=== 설치 완료 ===${NC}"
echo ""
echo "설치된 파일:"
echo "  CLAUDE.md"
echo "  .claude/commands/wbft-review-code.md"
echo "  .claude/docs/ (8개 문서)"
echo "  .claude/skills/wbft-system-contract-workflow/ (SKILL.md + references 6개)"
echo ""
echo "사용법:"
echo "  cd $TARGET_DIR"
echo "  claude"
echo "  /wbft-review-code [질문]"
