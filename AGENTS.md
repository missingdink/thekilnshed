# AGENTS.md

Guidance for coding agents working in this repository. See README.md for human-oriented setup and environment reference.

## Mandatory code search policy

For any task that requires discovering existing code, locating implementations,
finding call sites, understanding cross-file architecture, or avoiding duplicate
logic, use the `mcp__chunkhound__search` tool before using Grep, Glob, Read, or Bash.

Skip ChunkHound when the target is already known: exact symbol name, specific file
path from an error message, or explicit user direction. Go directly to grepika or Read.

Use ChunkHound first for:
- feature discovery
- symbol discovery
- architecture research
- similar-code lookup
- call-site lookup
- unfamiliar subsystem exploration

After ChunkHound identifies candidate files, use grepika get/context for verification.

### File Reading Strategy

Use the best tool for each task; avoid unnecessary token usage.

- Known small files: Read
- Large files, specific sections: grepika get/context with line ranges
- Code discovery (patterns, keywords): chunkhound search
- Symbol tracing (callers, references): grepika refs
- File structure overview: grepika outline or toc
- Binary files (images, PDFs): Read

Avoid speculative reads. Know what you need before you fetch it.

## Commands

Use `just` as the primary interface. Run `just` with no arguments to see all available commands.

```bash
bin/bridgetown                        # run dev server
bundle exec foreman start             # run server and cms
```

## Branches

- `main` is the marketing/public site.

## Architecture

### Structure

- **src** -- Bridgetown site source
- **src/admin/config.yml** -- DecapCMS configuration

### Key Patterns

- Tailwind CSS using design tokens from config (no hardcoded values)

### Rules for agents

1. **Never hardcode color or type values.** Read `design/tokens.json` for
   semantic foreground, background, and border colors and for typography.
   Use Tailwind classes that resolve to these tokens.
2. **Do not invent token values.** If a needed value is missing from
   tokens.json, flag it. Additions require a Figma update first. Never
   map tokens onto names or roles that Figma does not define.
3. **Token values come from Figma, not from this codebase.** Figma is the
   sole reference, owned by the lead designer. To update tokens, pull new
   values from the Figma file via MCP or REST API, then regenerate. Never
   edit token values by hand.

## Testing Conventions

- Unit tests: `*.test.{ts,tsx}` files
- Integration tests: `*.integration.test.{ts,tsx}` files
- Use `datatest-id` attribute (not `data-testid`)
- Test files typically in `_tests/` subdirectories
- See `docs/testing-setup.md` for full details

## Pull Requests

- Create a feature branch from `main` before making changes
- Never push directly to `main`
- Target PRs to `main`.
- No AI/IDE attribution in PR descriptions or commit messages

## Git

### Approval Gates

Stage files and create commits only when explicitly requested. Push to remote only when explicitly approved. A proposed message is not approval. Wait for explicit "commit" or "go ahead."

Avoid destructive commands unless specifically asked: force push, hard reset, rebase, revert, checkout -- (discarding changes), clean, branch -D.

### Commit Ownership

Attribute commits to the human developer. The commit history tells the project's story and should reflect human authorship and decision-making. No Co-Authored-By tags or AI attribution.

### Commit Scope

Keep commits focused on what was accomplished. The commit message captures a completed unit of work, not a roadmap. Future work belongs in issues or planning docs.

If the subject needs "and", it is two commits. Each commit captures one idea.

### Commit Messages

Follow Tim Pope's guide. Subject line: capitalized, imperative mood, 50 chars or less. Body: wrap at 72 chars, explain what and why.

Frame technical changes in terms of user value. Think "what can users do after this lands?" not "what code changed."

- Lead with a verb specific to what the commit actually does
- Rotate verbs: Introduce, Wire, Parse, Extract, Score, Model, Track, Enable, Capture
- No class names, file names, underscored identifiers, or code artifacts

Strip the implementation before writing the subject. Every commit has plumbing involved. The subject should not name it. Ask: if the reader knows nothing about the framework, provider, library, or internal module, does the subject still describe what the system can do?

Good: `Preserve decimal precision in checkout totals`
Bad: `Fix parseFloat rounding in createOrder.ts`

Good: `Resume conversation after network drop`
Bad: `Add WebSocket reconnect handler`

Some commits have no user-facing capability (dependency upgrades, tooling changes, CI config). Frame around what the change makes possible for the system itself: `Enforce type checks in CI`.

Do not use "Add" for every commit. Do not use "Improve" or "Update" as the subject verb when a more specific verb exists. "Improve parsing" is vague; "Parse notification tokens once per delivery" is a commit.

### Self-Contained Narrative

A commit message describes the state of the system after the commit lands. Do not rely on the reader having context for what came before or what comes after.

- No continuity words: "still," "now," "no longer," "continues to," "used to," "previously"
- No before/after contrast ("was X, now Y"). State what the code does.
- No previewing future commits ("Step 3 will..." or "later we'll...")
- No narrating the change ("moved X from A to B"). Describe where X lives and why that location is correct.
- No narrating documentation updates. Describe the decision or narrative captured, not the meta-action of updating.

A reader pulling this commit from `git log` months from now has no conversation context. Write for them.

### What to Omit

- Process metrics: line counts, file counts, test counts, number of review rounds
- Implementation details: file paths (describe by role), variable names, constant names, internal code references
- Vendor/tool names unless load-bearing. If the commit makes sense with the vendor replaced by a role ("the object storage backend," "the queue adapter"), use the role or drop it entirely. Exceptions: dependency version bumps (`Upgrade Next.js to 16`), infrastructure migrations (`Migrate workers from Heroku to Fly`), new integrations (`Wire Segment for analytics`).
- Counts in commit bodies ("73 files," "220 fixtures"). Describe what, not how many.

### Capture Commits

Some commits deliver a reference artifact rather than a behavior change: baselines, inventories, snapshots, fixtures, design tokens, benchmark results. The body describes what the artifact represents (construct, scope, purpose) without citing counts or metrics.

Acceptable subject verbs: Baseline, Record, Capture, Curate, Snapshot, Import, Collect.

Distinguish from behavior commits: if the commit changes how the system works, not what reference data it holds, use behavior-commit framing instead.

## Docs

```
docs/
  plans/        # Problem statements organized by urgency
    now/        # Before anyone writes feature code
    next/       # High-leverage prep once baseline is set
    later/      # Team-phase work
    shipped/    # Completed plans
  audits/       # Active audit results being worked through
                # Delete each doc when resolution is complete
```

## Writing Style

No em-dashes in prose. Use periods, semi-colons, or rewrite.
