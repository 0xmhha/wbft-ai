# wbft-ai — go-wbft Claude Code Plugin

Claude Code configuration package for the [go-wbft](https://github.com/wemixarchive/go-wbft) blockchain client.

When installed into the go-wbft project root, Claude Code gains accurate understanding of the codebase — distinguishing WBFT consensus from geth, wemixgov from systemcontracts, and referencing only the 165 packages/791 files that are actually included in the build.

## What This Provides

- **Project Context** (`CLAUDE.md`) — Project overview, hardfork chain, and go-wbft-specific code map
- **Code Review Command** (`.claude/commands/wbft-review-code.md`) — `/wbft-review-code` slash command for structured code analysis, call-flow tracing, and impact assessment
- **Build Reference** (`.claude/docs/build-source-files.md`) — Complete list of 165 packages and 791 Go files in the binary build
- **Review Guide** (`.claude/docs/review-guide.md`) — Question-type exploration guide and go-wbft unique code map
- **Dev Guide** (`.claude/docs/dev-basics.md`) — Build system, architecture, interfaces, tests, linting
- **WBFT Consensus** (`.claude/docs/wbft-consensus.md`) — State machine, WBFTExtra, RPC API, P2P, Epoch/Validator management
- **WBFT Features** (`.claude/docs/wbft-features.md`) — Governance contracts, hardforks, Fee Delegation, Brioche halving
- **Governance Flow** (`.claude/docs/governance-flow.md`) — wemixgov contract deployment and upgrade flow
- **Code Convention** (`.claude/docs/code-convention.md`) — Go and Solidity naming, formatting, commit messages
- **Ops Guide** (`.claude/docs/ops-guide.md`) — Genesis generation, key parameters, checklist

## Installation

> **Must be run from the go-wbft project root.**

### Method 1: One-liner (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/0xmhha/wbft-ai/main/install.sh | bash
```

Or specify the project path explicitly:

```bash
GO_WBFT_DIR=/path/to/go-wbft \
  curl -fsSL https://raw.githubusercontent.com/0xmhha/wbft-ai/main/install.sh | bash
```

### Method 2: Git Clone + Local Install

```bash
git clone https://github.com/0xmhha/wbft-ai.git
cd wbft-ai
./install-local.sh /path/to/go-wbft
```

### Method 3: Manual Install

```bash
cd /path/to/go-wbft
mkdir -p .claude/commands .claude/docs

BASE=https://raw.githubusercontent.com/0xmhha/wbft-ai/main

curl -fsSL $BASE/CLAUDE.md -o CLAUDE.md
curl -fsSL $BASE/.claude/commands/wbft-review-code.md -o .claude/commands/wbft-review-code.md
for doc in review-guide dev-basics wbft-consensus wbft-features governance-flow build-source-files code-convention ops-guide; do
  curl -fsSL $BASE/.claude/docs/${doc}.md -o .claude/docs/${doc}.md
done
```

## Usage

```bash
cd /path/to/go-wbft
claude
```

### Code Review Command

```
/wbft-review-code handleCommitMsg 함수의 동작을 설명해줘
/wbft-review-code WBFTExtra 구조체의 각 필드 역할은?
/wbft-review-code 거버넌스 컨트랙트 배포 흐름을 분석해줘
/wbft-review-code Croissant 하드포크에서 변경된 내용은?
```

The command supports:
- Function/type explanations
- Call-flow tracing
- Impact analysis for modifications
- WBFT consensus flow analysis
- Governance (wemixgov) contract architecture
- Transaction/EVM execution paths
- Genesis/chain configuration
- Hardfork and upgrade paths

## File Structure After Installation

```
go-wbft/
├── CLAUDE.md                              # Project context for Claude Code
└── .claude/
    ├── commands/
    │   └── wbft-review-code.md            # Code review slash command
    └── docs/
        ├── review-guide.md                # Question-type guide + go-wbft code map
        ├── dev-basics.md                  # Build, architecture, interfaces, tests
        ├── wbft-consensus.md              # WBFT consensus internals
        ├── wbft-features.md               # go-wbft unique features
        ├── governance-flow.md             # Governance contract flow
        ├── build-source-files.md          # Build target listing (165 pkg / 791 files)
        ├── code-convention.md             # Go & Solidity conventions
        └── ops-guide.md                   # Genesis generation & key parameters
```

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/0xmhha/wbft-ai/main/uninstall.sh | bash
```

Or run locally:

```bash
./uninstall.sh /path/to/go-wbft
```

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) installed
- [go-wbft](https://github.com/wemixarchive/go-wbft) project cloned locally

## Design Principles

1. **Token-efficient** — Docs split by topic; only relevant sections are loaded
2. **Build-based** — References only the 165 packages/791 files from `go list -deps`
3. **geth-distinct** — Clearly separates go-wbft unique code from geth origin
4. **Terminology-accurate** — `wemixgov` not `systemcontracts`, `gwemix` not `gstable`
5. **Index-driven** — Keyword → file → heading lookup table in the command file

## License

MIT
