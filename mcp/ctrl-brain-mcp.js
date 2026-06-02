#!/usr/bin/env node
const fs = require("fs");
const os = require("os");
const path = require("path");
const readline = require("readline");

const DEFAULT_BRAIN_FILE = path.join(os.homedir(), "SecondBrain", "captures", "SecondBrain.mdx");
const brainFile = process.env.CTRL_BRAIN_FILE || DEFAULT_BRAIN_FILE;

function ensureBrainFile() {
  fs.mkdirSync(path.dirname(brainFile), { recursive: true });
  if (!fs.existsSync(brainFile)) {
    fs.writeFileSync(brainFile, "---\ncontainerTag: \"my-second-brain\"\n---\n\n", "utf8");
  }
}

function readBrain() {
  ensureBrainFile();
  return fs.readFileSync(brainFile, "utf8");
}

function writeText(text) {
  ensureBrainFile();
  fs.appendFileSync(brainFile, text, "utf8");
}

function timestamp() {
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(new Date());
}

function appendEntry({ title, body, source }) {
  const cleanTitle = String(title || "Agent note").trim() || "Agent note";
  const cleanBody = String(body || "").trim();
  if (!cleanBody) throw new Error("body is required");

  const meta = source ? `${timestamp()}  ·  ${String(source).trim()}` : timestamp();
  writeText(`\n## ${cleanTitle}\n\n${meta}\n\n${cleanBody}\n`);
  return { path: brainFile, title: cleanTitle, bytes: Buffer.byteLength(cleanBody, "utf8") };
}

function searchBrain({ query, limit = 10, contextLines = 2 }) {
  const q = String(query || "").trim().toLowerCase();
  if (!q) throw new Error("query is required");

  const lines = readBrain().split(/\r?\n/);
  const matches = [];
  for (let i = 0; i < lines.length; i++) {
    if (!lines[i].toLowerCase().includes(q)) continue;
    const start = Math.max(0, i - contextLines);
    const end = Math.min(lines.length, i + contextLines + 1);
    matches.push({
      line: i + 1,
      text: lines[i],
      context: lines.slice(start, end).join("\n"),
    });
    if (matches.length >= limit) break;
  }
  return { path: brainFile, query, matches };
}

function tailBrain({ lines = 80 }) {
  const all = readBrain().split(/\r?\n/);
  const n = Math.max(1, Math.min(Number(lines) || 80, 500));
  return { path: brainFile, text: all.slice(-n).join("\n") };
}

function statBrain() {
  ensureBrainFile();
  const stat = fs.statSync(brainFile);
  return {
    path: brainFile,
    bytes: stat.size,
    modified: stat.mtime.toISOString(),
  };
}

const tools = [
  {
    name: "brain_status",
    description: "Return the Ctrl+Brain Markdown file path, size, and modified time.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
  },
  {
    name: "read_brain",
    description: "Read the full Ctrl+Brain Markdown file.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
  },
  {
    name: "tail_brain",
    description: "Read the last N lines of the Ctrl+Brain Markdown file.",
    inputSchema: {
      type: "object",
      properties: { lines: { type: "number", minimum: 1, maximum: 500 } },
      additionalProperties: false,
    },
  },
  {
    name: "search_brain",
    description: "Search the Ctrl+Brain Markdown file and return matching lines with context.",
    inputSchema: {
      type: "object",
      required: ["query"],
      properties: {
        query: { type: "string" },
        limit: { type: "number", minimum: 1, maximum: 100 },
        contextLines: { type: "number", minimum: 0, maximum: 10 },
      },
      additionalProperties: false,
    },
  },
  {
    name: "append_brain",
    description: "Append an agent-authored Markdown note into Ctrl+Brain.",
    inputSchema: {
      type: "object",
      required: ["body"],
      properties: {
        title: { type: "string" },
        body: { type: "string" },
        source: { type: "string" },
      },
      additionalProperties: false,
    },
  },
];

function toolResult(value) {
  return {
    content: [{ type: "text", text: typeof value === "string" ? value : JSON.stringify(value, null, 2) }],
  };
}

async function handle(message) {
  if (message.method === "initialize") {
    return {
      protocolVersion: "2024-11-05",
      capabilities: { tools: {} },
      serverInfo: { name: "ctrl-brain-local", version: "1.0.0" },
    };
  }
  if (message.method === "tools/list") {
    return { tools };
  }
  if (message.method === "tools/call") {
    const { name, arguments: args = {} } = message.params || {};
    if (name === "brain_status") return toolResult(statBrain());
    if (name === "read_brain") return toolResult(readBrain());
    if (name === "tail_brain") return toolResult(tailBrain(args));
    if (name === "search_brain") return toolResult(searchBrain(args));
    if (name === "append_brain") return toolResult(appendEntry(args));
    throw new Error(`unknown tool: ${name}`);
  }
  if (message.method && message.method.startsWith("notifications/")) {
    return undefined;
  }
  throw new Error(`unsupported method: ${message.method}`);
}

function send(payload) {
  process.stdout.write(`${JSON.stringify(payload)}\n`);
}

const rl = readline.createInterface({ input: process.stdin });
rl.on("line", async (line) => {
  if (!line.trim()) return;
  let message;
  try {
    message = JSON.parse(line);
    const result = await handle(message);
    if (message.id !== undefined && result !== undefined) {
      send({ jsonrpc: "2.0", id: message.id, result });
    }
  } catch (error) {
    if (message && message.id !== undefined) {
      send({
        jsonrpc: "2.0",
        id: message.id,
        error: { code: -32000, message: error.message || String(error) },
      });
    }
  }
});
