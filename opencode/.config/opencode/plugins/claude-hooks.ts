import { spawn } from "node:child_process"
import { existsSync, readFileSync, realpathSync } from "node:fs"
import { homedir } from "node:os"
import { basename, dirname, isAbsolute, join, resolve, sep } from "node:path"
import type { Plugin } from "@opencode/plugin"

type EditArgs = {
  path?: string
  content?: string
  oldString?: string
  newString?: string
  replaceAll?: boolean
}

type Result = { code: number; out: string; err: string }

type TextPart = { type: "text"; text: string }

type SystemPart = TextPart & { metadata?: Record<string, unknown> }

type InstructionEntry = { key?: unknown; text?: unknown }

type ToolResult = { output?: unknown; content?: unknown; metadata?: unknown }

const EDIT_TOOLS = new Set(["edit", "write"])

const PROFILE_ROOTS = [join(homedir(), ".claude"), join(homedir(), "dotfiles", "claude", ".claude")]

function profileFiles(): string[] {
  return PROFILE_ROOTS.flatMap((root) => [join(root, "CLAUDE.md"), join(root, "memory", "MEMORY.md")])
}

function claudePayload(args: EditArgs, directory: string): string {
  const file = args.path && !isAbsolute(args.path) ? join(directory, args.path) : args.path
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

function realTarget(file: string): string {
  let head = file
  const tail: string[] = []
  while (!existsSync(head) && dirname(head) !== head) {
    tail.unshift(basename(head))
    head = dirname(head)
  }
  return join(realpathSync(head), ...tail)
}

function protectedRoot(file: string): string | undefined {
  const target = realTarget(file)
  return PROFILE_ROOTS
    .map((root) => (existsSync(root) ? realpathSync(root) : root))
    .find((root) => target === root || target.startsWith(root + sep))
}

function instructionEntries(part: SystemPart): InstructionEntry[] {
  const experimental = part.metadata?.experimental as Record<string, unknown> | undefined
  const entries = experimental?.instructions
  return Array.isArray(entries) ? (entries as InstructionEntry[]) : []
}

function stripGlobalProfile(part: SystemPart): string {
  const profile = profileFiles()
  const verbatim = profile.reduce((text, file) => {
    if (!existsSync(file)) return text
    const block = `Instructions from: ${file}\n${readFileSync(file, "utf8")}`
    return text.replace(`${block}\n`, "").replace(`\n${block}`, "")
  }, part.text)
  const named = new Set(profile)
  return instructionEntries(part).reduce(
    (text, entry) =>
      typeof entry.key === "string" && named.has(entry.key) && typeof entry.text === "string" && entry.text !== ""
        ? text.replace(entry.text, "")
        : text,
    verbatim,
  )
}

function resultParts(result: ToolResult): TextPart[] {
  if (typeof result.content === "string") return [{ type: "text", text: result.content }]
  if (Array.isArray(result.content) && result.content.length > 0) return [...result.content] as TextPart[]
  if (result.output === undefined) return []
  const text = typeof result.output === "string" ? result.output : JSON.stringify(result.output) ?? String(result.output)
  return [{ type: "text", text }]
}

function runHook(script: string, payload: string, cwd: string): Promise<Result> {
  return new Promise((settle) => {
    const child = spawn("bash", [join(homedir(), ".claude", "hooks", script)], { cwd, detached: true })
    const timer = setTimeout(() => {
      if (!child.pid) return
      try {
        process.kill(-child.pid, "SIGKILL")
      } catch {}
    }, Number(process.env.CLAUDE_HOOKS_TIMEOUT_MS) || 60_000)
    let out = ""
    let err = ""
    child.stdout.on("data", (chunk) => (out += chunk))
    child.stderr.on("data", (chunk) => (err += chunk))
    child.on("error", (e) => {
      clearTimeout(timer)
      settle({ code: 127, out, err: err + String(e) })
    })
    child.on("close", (code) => {
      clearTimeout(timer)
      settle({ code: code ?? 1, out, err })
    })
    child.stdin.on("error", () => {})
    child.stdin.end(payload)
  })
}

const ClaudeHooks: Plugin = {
  id: "claude-hooks",
  setup: async (ctx) => {
    const directory = ctx.location.directory

    await ctx.session.hook("context", (event) => {
      event.system.forEach((part, index) => {
        const text = stripGlobalProfile(part as SystemPart)
        if (text !== part.text) event.system[index] = { ...part, text }
      })
    })

    await ctx.tool.hook("execute.before", async (event) => {
      if (!EDIT_TOOLS.has(event.tool)) return
      const args = (event.input ?? {}) as EditArgs
      const file = args.path
      if (typeof file === "string" && file) {
        const target = resolve(directory, file)
        const root = protectedRoot(target)
        if (root) {
          throw new Error(
            `${file} resolves under ${root}, the Claude Code profile, which opencode must not modify. Do not retry by any other means: tell the user.`,
          )
        }
        const old = args.oldString
        if (
          event.tool === "edit" &&
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
      const r = await runHook("prose-lint-pretool.sh", claudePayload(args, directory), directory)
      if (r.code === 2) throw new Error(r.err.trim() || "prose-lint-pretool.sh blocked this edit")
    })

    await ctx.tool.hook("execute.after", async (event) => {
      if (!EDIT_TOOLS.has(event.tool)) return
      if (event.status !== "completed") return
      const args = (event.input ?? {}) as EditArgs
      const r = await runHook("format-on-edit.sh", claudePayload(args, directory), directory)
      const report = (r.out + r.err).trim()
      if (!report) return
      const result = event.result as ToolResult
      event.result = {
        ...event.result,
        content: [...resultParts(result), { type: "text", text: `format-on-edit.sh:\n${report}` }],
      }
    })
  },
}

export default ClaudeHooks
