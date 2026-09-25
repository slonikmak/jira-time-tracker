// Минимальный MCP stdio-клиент (newline-delimited JSON-RPC) для pencil.
// Использование:
//   node pencil-mcp-client.mjs list
//   node pencil-mcp-client.mjs call <tool> '<json-args>'
import { spawn } from "node:child_process";

const SERVER_CMD = "C:\\Program Files\\Pen\\resources\\app.asar.unpacked\\out\\mcp-server-windows-x64.exe";
const SERVER_ARGS = ["--app", "desktop"];

const mode = process.argv[2];
const toolName = process.argv[3];
const toolArgs = process.argv[4] ? JSON.parse(process.argv[4]) : {};

const child = spawn(SERVER_CMD, SERVER_ARGS, { stdio: ["pipe", "pipe", "pipe"] });

let buffer = "";
const pending = new Map();
let nextId = 1;

function send(method, params) {
  const id = nextId++;
  const msg = JSON.stringify({ jsonrpc: "2.0", id, method, params }) + "\n";
  child.stdin.write(msg);
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    setTimeout(() => { if (pending.has(id)) { pending.delete(id); reject(new Error("timeout " + method)); } }, 25000);
  });
}
function notify(method, params) {
  child.stdin.write(JSON.stringify({ jsonrpc: "2.0", method, params }) + "\n");
}

child.stderr.on("data", (d) => process.stderr.write("[server-stderr] " + d));
child.stdout.on("data", (d) => {
  buffer += d.toString();
  let idx;
  while ((idx = buffer.indexOf("\n")) !== -1) {
    const line = buffer.slice(0, idx).trim();
    buffer = buffer.slice(idx + 1);
    if (!line) continue;
    let msg;
    try { msg = JSON.parse(line); } catch (e) { process.stderr.write("[parse-skip] " + line.slice(0, 200) + "\n"); continue; }
    if (msg.id && pending.has(msg.id)) {
      const p = pending.get(msg.id);
      pending.delete(msg.id);
      if (msg.error) p.reject(new Error(JSON.stringify(msg.error)));
      else p.resolve(msg.result);
    }
  }
});

try {
  await send("initialize", {
    protocolVersion: "2024-11-05",
    capabilities: {},
    clientInfo: { name: "cline-manual-client", version: "1.0.0" },
  });
  notify("notifications/initialized", {});
  if (mode === "list") {
    const res = await send("tools/list", {});
    console.log(JSON.stringify(res, null, 2));
  } else if (mode === "call") {
    const res = await send("tools/call", { name: toolName, arguments: toolArgs });
    console.log(JSON.stringify(res, null, 2));
  } else {
    console.error("usage: list | call <tool> '<json>'");
    process.exitCode = 2;
  }
} catch (e) {
  console.error("ERROR: " + e.message);
  process.exitCode = 1;
} finally {
  child.kill();
}
