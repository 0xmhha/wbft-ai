# Contributing to wbft-ai

## Reporting Issues

Open a [GitHub Issue](https://github.com/0xmhha/wbft-ai/issues) and include:

- Claude Code version (`claude --version`)
- go-wbft commit hash (`git rev-parse HEAD` in the go-wbft repo)
- Steps to reproduce the problem
- What you expected vs. what happened

## Submitting Pull Requests

1. Fork the repository and create a branch from `main`:
   ```
   git checkout -b feat/your-change
   ```
2. Make your changes (see guidelines below).
3. Open a PR against `main`. Use a conventional commit-style title (see below).

Keep PRs focused — one logical change per PR.

## Development Setup

```bash
# Clone
git clone https://github.com/0xmhha/wbft-ai.git
cd wbft-ai

# Test locally against your go-wbft clone
./install-local.sh /path/to/go-wbft

# Verify the slash command loads correctly inside that project
# Open Claude Code in go-wbft and run /wbft-review-code
```

Use `uninstall.sh` to clean up before reinstalling:

```bash
./uninstall.sh /path/to/go-wbft
```

> **Note:** The path argument is required. Without it, the script defaults to the current directory and will remove `.claude/` and `CLAUDE.md` from wherever you run it.

## Updating Documentation

The docs live in `.claude/docs/`. A few rules:

- **Keep files lean** — 500 lines max per file. Split into a new doc if needed. (`build-source-files.md` is auto-generated and exempt.)
- **Section numbers** — New sections in existing docs use the next available `§N` number (e.g., `§19`, `§20`). Do not renumber existing sections.
- **Keyword index** — `.claude/commands/wbft-review-code.md` contains a keyword-to-section index. Update it whenever you add or rename a section.
- **Test before opening a PR** — Install locally with `install-local.sh`, open Claude Code in go-wbft, and confirm `/wbft-review-code` behaves as expected with the changed content.
- **`CLAUDE.md`** — Project-level context doc. Edit only for project-scope changes (new docs added, install path changes, etc.).

## Commit Message Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>: <short description>

[optional body]
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`

Examples:

```
docs: add §19 slashing-conditions section to wbft-features
fix: correct install path detection in install-local.sh
chore: update keyword index for new governance sections
```

- Write in English.
- Keep the subject line under 72 characters.
- No co-author lines.

## Code of Conduct

This project follows the [Contributor Covenant v2.1](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).
