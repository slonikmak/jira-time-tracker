// Минимальный MCP stdio-клиент для сервера open-design из настроек Cline.
// Использование:
//   node od-mcp-client.mjs list                      — список инструментов
//   node od-mcp-client.mjs call <tool> '<json-args>' — вызов инструмента
import { spawn } from "node:child_process";

const SERVER_CMD = "C:\\Users\\kp\\AppData\\Roaming\\Open Design\\en\\2207140263b0217a\\Open Design.exe";
const SERVER_ARGS = [
  "C:\\Users\\kp\\AppData\\Roaming\\Open Design\\launcher\\channels\\stable\\namespaces\\release-stable-win\\versions\\0.23.0\\payload\\resources\\app\\prebundled\\daemon\\daemon-cli.mjs",
  "mcp",
];
const SERVER_ENV = {
  ...process.env,
  OD_DAEMON_URL: "http://127.0.0.1:50969",
  OD_DATA_DIR: "C:\\Users\\kp\\AppData\\Roaming\\Open Design\\namespaces\\release-stable-win\\data",
  OD_MCP_BOOTSTRAP_COMMAND: "C:\\Users\\kp\\AppData\\Local\\Programs\\Open Design\\Open Design.exe",
  OD_MCP_BOOTSTRAP_ARGS: '["--headless"]',
  ELECTRON_RUN_AS_NODE: "1",
};

const mode = process.argv[2]; // "list" | "call"
const toolName = process.argv[3];
const toolArgs = process.argv[4] ? JSON.parse(process.argv[4]) : {};

const child = spawn(SERVER_CMD, SERVER_ARGS, { env: SERVER_ENV, stdio: ["pipe", "pipe", "pipe"] });

let buffer = Buffer.alloc(0);
const pending = new Map();
let nextId = 1;

function send(method, params) {
  const id = nextId++;
  const msg = JSON.stringify({ jsonrpc: "2.0", id, method, params });
  child.stdin.write(`Content-Length: ${Buffer.byteLength(msg)}\r\n\r\n${msg}`);
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    setTimeout(() => { if (pending.has(id)) { pending.delete(id); reject(new Error("timeout " + method)); } }, 55000);
  });
}
function notify(method, params) {
  const msg = JSON.stringify({ jsonrpc: "2.0", method, params });
  child.stdin.write(`Content-Length: ${Buffer.byteLength(msg)}\r\n\r\n${msg}`);
}

child.stderr.on("data", (d) => process.stderr.write("[server] " + d));
child.stdout.on("data", (d) => {
  buffer = Buffer.concat([buffer, d]);
  for (;;) {
    const headerEnd = buffer.indexOf("\r\n\r\n");
    if (headerEnd === -1) break;
    const header = buffer.slice(0, headerEnd).toString();
    const m = /Content-Length: (\d+)/i.exec(header);
    if (!m) { buffer = buffer.slice(headerEnd + 4); continue; }
    const len = parseInt(m[1], 10);
    if (buffer.length < headerEnd + 4 + len) break;
    const body = buffer.slice(headerEnd + 4, headerEnd + 4 + len).toString();
    buffer = buffer.slice(headerEnd + 4 + len);
    const msg = JSON.parse(body);
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
