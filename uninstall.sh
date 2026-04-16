#!/bin/bash
# go-wbft Claude Code 플러그인 제거 스크립트
# 사용법: ./uninstall.sh /path/to/go-wbft

set -e

TARGET_DIR="${1:-${GO_WBFT_DIR:-}}"

if [ -z "$TARGET_DIR" ]; then
    echo "사용법: $0 /path/to/go-wbft"
    exit 1
fi

echo "=== go-wbft Claude Code 플러그인 제거 ==="

if [ -d "$TARGET_DIR/.claude" ]; then
    rm -rf "$TARGET_DIR/.claude"
    echo "삭제: $TARGET_DIR/.claude/"
fi

if [ -f "$TARGET_DIR/CLAUDE.md" ]; then
    rm "$TARGET_DIR/CLAUDE.md"
    echo "삭제: $TARGET_DIR/CLAUDE.md"
fi

echo "=== 제거 완료 ==="
