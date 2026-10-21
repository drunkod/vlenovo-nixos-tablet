// Execute using 'node smoke-test.mjs'. Spawns a temporary loopback server.
// Verifies remote POST -> scene reducer -> live SSE push; no tablet changes.
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { randomBytes } from "node:crypto";
import { setTimeout as delay } from "node:timers/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const dir = dirname(fileURLToPath(import.meta.url));
const token = randomBytes(30).toString("base64url");
const port = 17859;
const base = "http://127.0.0.1:" + port;
const processHandle = spawn(process.execPath, [join(dir, "server.mjs")], {
  cwd: dir,
  env: { ...process.env, SCENE_PORT: String(port), SCENE_TOKEN: token, SCENE_BIND: "127.0.0.1" },
  stdio: ["ignore", "pipe", "pipe"]
});
const request = async (change, hdrs = {}) =>
  fetch(base + "/api/scene", {
    method: "POST",
    headers: { "Content-Type": "application/json", "X-Scene-Token": token, ...hdrs },
    body: JSON.stringify(change)
  });
const controller = new AbortController();
try {
  let ready = false;
  for (let i = 0; i < 60; i++) {
    await delay(100);
    try { ready = (await fetch(base + "/health")).ok; } catch {}
    if (ready) break;
  }
  assert.ok(ready, "Server did not become ready");
  const streamed = await fetch(base + "/api/stream", { signal: controller.signal });
  assert.equal(streamed.status, 200);
  assert.match(streamed.headers.get("content-type"), /text\/event-stream/);
  const reader = streamed.body.getReader();
  const read = async () => {
    const result = await Promise.race([reader.read(), delay(4000).then(() => { throw Error("SSE timed out"); })]);
    return new TextDecoder().decode(result.value || new Uint8Array());
  };
  assert.match(await read(), /"seq":1/);
  assert.equal((await fetch(base + "/api/scene", { method: "POST", headers: {"Content-Type":"application/json"}, body:"{}" })).status, 401);
  assert.equal((await request({ shell: "rm -rf /" })).status, 400);
  assert.equal((await request({ mode: "orbit" }, { Origin: "https://untrusted.example" })).status, 403);
  const change = await request({ mode: "tide", hue: 100, energy: 1.5, label: "Hello, Lenovo!", pulse: true });
  assert.equal(change.status, 200);
  assert.equal((await change.json()).seq, 2);
  let buf = "";
  for (let i = 0; i < 5 && !buf.includes('"seq":2'); i++) buf += await read();
  assert.match(buf, /"mode":"tide"/);
  assert.match(buf, /"seq":2/);
  const state = await (await fetch(base + "/api/state")).json();
  assert.equal(state.label, "Hello, Lenovo!");
  assert.equal((await fetch(base + "/viewer")).status, 200);
  assert.equal((await fetch(base + "/controller")).status, 200);
  assert.equal((await fetch(base + "/../../etc/passwd")).status, 404);
  console.log("PASS: auth, validation, origin protection, SSE live push, viewer, controller and unknown paths");
} finally {
  controller.abort();
  processHandle.kill("SIGTERM");
  await delay(150);
}
