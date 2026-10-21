// Dependency-free Mac prototype of the future Rust tablet scene-controller.
// Node 22+; local-only by default. No DRM, NixOS or firmware changes.
import http from "node:http";
import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { randomBytes, timingSafeEqual } from "node:crypto";

const here = dirname(fileURLToPath(import.meta.url));
const host = process.env.SCENE_BIND || "127.0.0.1";
const port = Number(process.env.SCENE_PORT || 17858);
const token = process.env.SCENE_TOKEN || randomBytes(24).toString("base64url");
if (!Number.isInteger(port) || port < 1024 || port > 65535) throw Error("SCENE_PORT must be 1024..65535");
if (token.length < 16) throw Error("SCENE_TOKEN must have at least 16 characters");
if (host !== "127.0.0.1" && host !== "::1" && process.env.SCENE_ALLOW_LAN !== "yes") {
  throw Error("Non-loopback bind needs explicit SCENE_ALLOW_LAN=yes; use only on a trusted isolated LAN");
}

let scene = { mode: "breathe", hue: 0, energy: 0.3, label: "Ready for your next idea", pulse: false, seq: 1 };
const listeners = new Set();
const attempts = new Map();
const files = new Map([
  ["/", ["web/viewer.html", "text/html; charset=utf-8"]],
  ["/viewer", ["web/viewer.html", "text/html; charset=utf-8"]],
  ["/controller", ["web/controller.html", "text/html; charset=utf-8"]]
]);
const headers = {
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "no-referrer",
  "Cache-Control": "no-store",
  "Content-Security-Policy": "default-src 'none'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'"
};
function json(res, status, payload) {
  res.writeHead(status, { ...headers, "Content-Type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(payload));
}
function auth(req) {
  const given = req.headers["x-scene-token"];
  if (typeof given !== "string") return false;
  const a = Buffer.from(given), b = Buffer.from(token);
  return a.length === b.length && timingSafeEqual(a, b);
}
function sameOrigin(req) {
  const origin = req.headers.origin;
  if (!origin) return true; // curl and local CLI still require valid secret
  try { return new URL(origin).host === req.headers.host; } catch { return false; }
}
function throttle(req) {
  const who = req.socket.remoteAddress ?? "?";
  const now = Date.now();
  const bucket = (attempts.get(who) ?? []).filter(t => now - t < 10_000);
  bucket.push(now);
  attempts.set(who, bucket);
  return bucket.length > 25;
}
function validated(data) {
  if (data === null || typeof data !== "object" || Array.isArray(data)) throw Error("Expected JSON object");
  const allowed = new Set(["mode", "hue", "energy", "label", "pulse"]);
  for (const key of Object.keys(data)) if (!allowed.has(key)) throw Error("Unknown field " + key);
  if (Object.hasOwn(data, "mode") && !["breathe", "orbit", "tide"].includes(data.mode))
    throw Error("mode must be breathe, orbit or tide");
  if (Object.hasOwn(data, "hue") && (typeof data.hue !== "number" || !Number.isInteger(data.hue) || data.hue < -180 || data.hue > 180))
    throw Error("hue must be integer -180..180");
  if (Object.hasOwn(data, "energy") && (typeof data.energy !== "number" || !Number.isFinite(data.energy) || data.energy < 0 || data.energy > 2))
    throw Error("energy must be number 0..2");
  if (Object.hasOwn(data, "label") && (typeof data.label !== "string" || data.label.length > 80 || /[\u0000-\u001f]/.test(data.label)))
    throw Error("label must be printable text up to 80 characters");
  if (Object.hasOwn(data, "pulse") && typeof data.pulse !== "boolean")
    throw Error("pulse must be boolean");
  return data;
}
function broadcast() {
  const msg = "id: " + scene.seq + "\ndata: " + JSON.stringify(scene) + "\n\n";
  for (const res of listeners) { try { res.write(msg); } catch { listeners.delete(res); } }
}
const server = http.createServer(async (req, res) => {
  try {
    const path = new URL(req.url, "http://localhost").pathname;
    if (req.method === "GET" && files.has(path)) {
      const [file, type] = files.get(path);
      const body = await readFile(join(here, file));
      res.writeHead(200, { ...headers, "Content-Type": type });
      res.end(body); return;
    }
    if (req.method === "GET" && (path === "/health" || path === "/api/state")) {
      json(res, 200, path === "/health" ? { ok: true, clientCount: listeners.size } : scene); return;
    }
    if (req.method === "GET" && path === "/api/stream") {
      if (listeners.size >= 16) { json(res, 503, { error: "Too many viewers" }); return; }
      res.writeHead(200, {
        ...headers, "Content-Type": "text/event-stream",
        "Connection": "keep-alive", "X-Accel-Buffering": "no"
      });
      res.write("retry: 1500\n\n");
      listeners.add(res);
      res.write("id: " + scene.seq + "\ndata: " + JSON.stringify(scene) + "\n\n");
      req.on("close", () => listeners.delete(res)); return;
    }
    if (req.method === "POST" && path === "/api/scene") {
      if (!sameOrigin(req)) { json(res, 403, { error: "Invalid Origin" }); return; }
      if (!auth(req)) { json(res, 401, { error: "Wrong or missing token" }); return; }
      if (throttle(req)) { json(res, 429, { error: "Slow down" }); return; }
      if (!req.headers["content-type"]?.startsWith("application/json")) {
        json(res, 415, { error: "Use application/json" }); return;
      }
      let body = "";
      for await (const chunk of req) {
        body += chunk.toString("utf8");
        if (body.length > 2048) { json(res, 413, { error: "JSON too large" }); return; }
      }
      let change;
      try { change = validated(JSON.parse(body)); }
      catch (err) { json(res, 400, { error: err.message }); return; }
      scene = { ...scene, ...change, seq: scene.seq + 1 };
      broadcast(); json(res, 200, scene); return;
    }
    json(res, 404, { error: "Not found" });
  } catch (err) {
    console.error("Request failed:", err.message);
    if (!res.headersSent) json(res, 500, { error: "Internal server error" });
    else res.end();
  }
});
server.on("clientError", (error, socket) => socket.end("HTTP/1.1 400 Bad Request\r\n\r\n"));
const timer = setInterval(() => {
  for (const res of listeners) { try { res.write(": alive\n\n"); } catch { listeners.delete(res); } }
  const cutoff = Date.now() - 15_000;
  for (const [key, vals] of attempts) if (vals.at(-1) < cutoff) attempts.delete(key);
}, 15_000);
timer.unref();
server.listen(port, host, () => {
  console.log("Living tablet demo on http://" + host + ":" + port + "/viewer");
  console.log("Controller: http://" + host + ":" + port + "/controller");
  console.log("Token (enter in controller; not stored): " + token);
  console.log("Generation 58 is not touched.");
});
