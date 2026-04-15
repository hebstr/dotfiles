Synthesize this conversation into a handoff document, then generate a continuation prompt.

## Step 1 — Handoff document

Create a file called `CONTINUATION-PROMPT.md` in the current working directory.
Structure it as follows:

```markdown
# Session handoff — [short title describing the work done]

## Context
What project/files we were working on and why.

## Key decisions
Bullet list of non-obvious choices made during this session and their rationale.

## Current state
What was accomplished. Reference specific files and line numbers where relevant.

## Open items
What remains to be done, ordered by priority. Include any blockers or questions.

## Continuation prompt
A ready-to-use prompt (fenced in a code block) that a fresh Claude Code session can receive to pick up where we left off. The prompt should:
- Set the context in 2-3 sentences
- List the remaining tasks explicitly
- Reference the key files involved
- Mention any constraints or decisions to preserve
```

## Step 2 — Confirm

After writing the file, print its full contents so the user can review it before starting a new session.

## Rules
- Write in English (this is a technical handoff, not conversation)
- Be precise: file paths, function names, line numbers — not vague summaries
- The continuation prompt must be self-contained (a new session has zero context)
- Do not include anything the new session can derive by reading the code — focus on intent, decisions, and remaining work
