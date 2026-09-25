// Временный клиент stdio MCP сервера Pen (pen.dev).
// Использование:
//   node pen-mcp.js                      — список инструментов
//   node pen-mcp.js schemas              — схемы инструментов
//   node pen-mcp.js call <tool> [argsFile] — вызов инструмента; аргументы — JSON из файла
const { spawn } = require('child_process');
const fs = require('fs');

const exe = 'C:\\Program Files\\Pen\\resources\\app.asar.unpacked\\out\\mcp-server-windows-x64.exe';
const proc = spawn(exe, ['--app', 'desktop', '--agent', 'claudeCodeCLI'], { stdio: ['pipe', 'pipe', 'pipe'] });

let buf = '';
const pending = new Map();
let nextId = 1;

function sendLine(obj) {
  proc.stdin.write(JSON.stringify(obj) + '\n');
}

function send(method, params) {
  const id = nextId++;
  sendLine({ jsonrpc: '2.0', id, method, params });
  return new Promise((resolve) => pending.set(id, { resolve }));
}

proc.stdout.on('data', (chunk) => {
  buf += chunk.toString('utf8');
  for (;;) {
    const nl = buf.indexOf('\n');
    if (nl < 0) break;
    const line = buf.slice(0, nl).trim();
    buf = buf.slice(nl + 1);
    if (!line) continue;
    try {
      const msg = JSON.parse(line);
      if (msg.id != null && pending.has(msg.id)) {
        pending.get(msg.id).resolve(msg);
        pending.delete(msg.id);
      }
    } catch (e) { /* не JSON */ }
  }
});

proc.stderr.on('data', () => {});

async function callTool(name, args) {
  return send('tools/call', { name, arguments: args || {} });
}

function extractText(res) {
  if (res.error) return 'MCP_ERROR: ' + JSON.stringify(res.error);
  const parts = (res.result && res.result.content) || [];
  return parts.map((p) => (p.type === 'text' ? p.text : JSON.stringify(p))).join('\n');
}

(async () => {
  try {
    await send('initialize', {
      protocolVersion: '2024-11-05',
      capabilities: {},
      clientInfo: { name: 'cline-manual', version: '1.0.0' },
    });
    sendLine({ jsonrpc: '2.0', method: 'notifications/initialized', params: {} });

    const mode = process.argv[2];
    if (mode === 'call') {
      const tool = process.argv[3];
      const args = process.argv[4] ? JSON.parse(fs.readFileSync(process.argv[4], 'utf8').replace(/^﻿/, '')) : {};
      const res = await callTool(tool, args);
      const text = extractText(res);
      if (text.length > 20000) {
        const out = `C:\\Users\\kp\\Documents\\projects\\jira-time-tracker\\.scratch\\pen-out-${Date.now()}.txt`;
        fs.writeFileSync(out, text);
        console.log('LONG_OUTPUT_SAVED: ' + out + ' (' + text.length + ' chars)');
        console.log(text.slice(0, 4000));
      } else {
        console.log(text);
      }
    } else {
      const tools = await send('tools/list', {});
      if (mode === 'schemas') {
        console.log(JSON.stringify(tools.result.tools.map((t) => ({ name: t.name, schema: t.inputSchema })), null, 1));
      } else {
        for (const t of tools.result.tools) {
          console.log('-', t.name, '::', (t.description || '').slice(0, 200).replace(/\n/g, ' '));
        }
      }
    }
  } catch (e) {
    console.error('ERROR', e);
    process.exitCode = 1;
  } finally {
    proc.kill();
    process.exit();
  }
})();

setTimeout(() => { console.error('TIMEOUT'); process.exit(2); }, 120000);
