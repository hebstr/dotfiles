import type { Plugin } from "@opencode-ai/plugin"
import { spawn } from "node:child_process"
import { existsSync, readFileSync, realpathSync } from "node:fs"
import { homedir } from "node:os"
import { basename, dirname, isAbsolute, join, resolve, sep } from "node:path"

type EditArgs = {
  filePath?: string
  content?: string
  oldString?: string
  newString?: string
  replaceAll?: boolean
}

type Result = { code: number; out: string; err: string }

const EDIT_TOOLS = new Set(["edit", "write"])

const PROFILE_ROOTS = [join(homedir(), ".claude"), join(homedir(), "dotfiles", "claude", ".claude")]

// The Claude Code hook scripts read the PreToolUse/PostToolUse payload on stdin,
// so the opencode arguments are translated into that shape and the scripts run unchanged.
// Only the plugin is exported: opencode calls every export of a plugin module as a plugin.
function claudePayload(args: EditArgs, directory: string): string {
  const file =
    args.filePath && !isAbsolute(args.filePath) ? join(directory, args.filePath) : args.filePath
  // opencode's edit creates a missing file from newString when oldString is empty, which
  // Claude Code's Edit never does: the hook sees it as the Write it amounts to.
  if (args.oldString === "" && file && !existsSync(file)) {
    return JSON.stringify({ tool_input: { file_path: file, content: args.newString } })
  }
  return JSON.stringify({
    tool_input: {
      file_path: file,
      content: args.content,
      old_string: args.oldString,
      new_string: args.newString,
      replace_all: args.replaceAll,
    },
  })
}

// A file about to be created does not exist yet, so the nearest existing ancestor is
// resolved and the missing tail appended: symlinks into the profile are caught either way.
function realTarget(file: string): string {
  let head = file
  const tail: string[] = []
  while (!existsSync(head) && dirname(head) !== head) {
    tail.unshift(basename(head))
    head = dirname(head)
  }
  return join(realpathSync(head), ...tail)
}

// opencode matches `edit` permission patterns against a path relative to the project,
// so no pattern can name these directories from every project: the guard lives here.
function protectedRoot(file: string): string | undefined {
  const target = realTarget(file)
  return PROFILE_ROOTS
    .map((root) => (existsSync(root) ? realpathSync(root) : root))
    .find((root) => target === root || target.startsWith(root + sep))
}

// Outside a git repository opencode resolves the relative `instructions` entries by walking
// up to `/`, which reaches the global profile under `~` and injects the files AGENTS.md exists
// to keep out; inside ~/dotfiles/claude the walk finds the same files under their stow source.
// The system prompt arrives here as one joined string, so each block is rebuilt
// exactly as instruction.ts writes it and removed verbatim; a changed format removes nothing.
function stripGlobalProfile(system: string): string {
  const profile = PROFILE_ROOTS.flatMap((root) => [join(root, "CLAUDE.md"), join(root, "memory", "MEMORY.md")])
  return profile.reduce((text, file) => {
    if (!existsSync(file)) return text
    const block = `Instructions from: ${file}\n${readFileSync(file, "utf8")}`
    return text.replace(`${block}\n`, "").replace(`\n${block}`, "")
  }, system)
}

function runHook(script: string, payload: string, cwd: string): Promise<Result> {
  return new Promise((resolve) => {
    const child = spawn("bash", [join(homedir(), ".claude", "hooks", script)], { cwd, detached: true })
    // A formatter the script started keeps the pipes open after bash dies, and "close" waits
    // for them: the whole process group is killed, and the timeout stays advisory, as in Claude Code.
    const timer = setTimeout(() => {
      if (!child.pid) return
      try {
        process.kill(-child.pid, "SIGKILL")
      } catch {}
    }, 60_000)
    let out = ""
    let err = ""
    child.stdout.on("data", (chunk) => (out += chunk))
    child.stderr.on("data", (chunk) => (err += chunk))
    child.on("error", (e) => {
      clearTimeout(timer)
      resolve({ code: 127, out, err: err + String(e) })
    })
    child.on("close", (code) => {
      clearTimeout(timer)
      resolve({ code: code ?? 1, out, err })
    })
    // A hook may exit before reading stdin (prose-lint-pretool.sh does when prose-lint is
    // absent); the resulting EPIPE would otherwise be an unhandled error that kills opencode.
    child.stdin.on("error", () => {})
    child.stdin.end(payload)
  })
}

export const ClaudeHooks: Plugin = async ({ directory }) => ({
  // request.ts keeps its own reference to this array, so it is edited in place.
  "experimental.chat.system.transform": async (_input, output) => {
    output.system.forEach((text, i) => {
      output.system[i] = stripGlobalProfile(text)
    })
  },
  "tool.execute.before": async (input, output) => {
    if (!EDIT_TOOLS.has(input.tool)) return
    const file = output.args?.filePath
    if (typeof file === "string" && file) {
      const root = protectedRoot(resolve(directory, file))
      if (root) {
        throw new Error(
          `${file} resolves under ${root}, the Claude Code profile, which opencode must not modify. Do not retry by any other means: tell the user.`,
        )
      }
      // opencode's edit falls back to fuzzy matches, while the hook replays oldString verbatim:
      // without a verbatim match it would lint the file as it was before the edit.
      const target = resolve(directory, file)
      const old = output.args.oldString
      if (
        input.tool === "edit" &&
        /\.(md|qmd|Rmd)$/.test(file) &&
        typeof old === "string" &&
        old !== "" &&
        existsSync(target) &&
        !readFileSync(target, "utf8").includes(old)
      ) {
        throw new Error(
          `oldString does not occur verbatim in ${file}, so prose-lint cannot check this edit. Re-read the file and retry with the exact text, including whitespace and line endings.`,
        )
      }
    }
    const r = await runHook("prose-lint-pretool.sh", claudePayload(output.args, directory), directory)
    // Exit 2 is Claude Code's blocking signal; any other failure stays advisory, as there.
    if (r.code === 2) throw new Error(r.err.trim() || "prose-lint-pretool.sh blocked this edit")
  },
  "tool.execute.after": async (input, output) => {
    if (!EDIT_TOOLS.has(input.tool)) return
    const r = await runHook("format-on-edit.sh", claudePayload(input.args, directory), directory)
    const report = (r.out + r.err).trim()
    if (report) output.output = `${output.output}\n\nformat-on-edit.sh:\n${report}`
  },
})
