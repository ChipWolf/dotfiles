#!/usr/bin/env node
// Loopback HTTP server that captures the first POST /v1/messages body sent
// by `claude`, writes the JSON body to $CAPTURE_OUT, replies with a minimal
// valid stop_reason=end_turn response, then exits.
//
// Usage:
//   CAPTURE_OUT=/path/to/out.json node lib/claude-loopback.mjs &
//   server_pid=$!
//   # Wait for /tmp/agent-audit-claude-port file or read first stdout line
//   ANTHROPIC_BASE_URL=http://127.0.0.1:<port> ANTHROPIC_API_KEY=dummy claude -p hi
//   wait $server_pid

import { createServer } from "node:http";
import { writeFileSync } from "node:fs";

const out = process.env.CAPTURE_OUT;
if (!out) {
  console.error("CAPTURE_OUT env var required");
  process.exit(2);
}

let captured = false;

const server = createServer((req, res) => {
  let body = "";
  req.setEncoding("utf8");
  req.on("data", (chunk) => (body += chunk));
  req.on("end", () => {
    const url = req.url || "";
    console.error(`loopback: ${req.method} ${url}`);

    // Capture the first POST /v1/messages body.
    if (url.includes("/v1/messages") && req.method === "POST" && !captured) {
      captured = true;
      writeFileSync(out, body);
      const reply = {
        id: "msg_audit",
        type: "message",
        role: "assistant",
        model: "claude-audit",
        content: [{ type: "text", text: "ok" }],
        stop_reason: "end_turn",
        stop_sequence: null,
        usage: { input_tokens: 0, output_tokens: 1 },
      };
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify(reply));
      setTimeout(() => {
        server.close();
        process.exit(0);
      }, 50);
      return;
    }

    // Respond to anything else (e.g. /v1/models, capability probes) with a
    // generous default so claude doesn't bail before sending /v1/messages.
    if (url.includes("/v1/models")) {
      res.writeHead(200, { "content-type": "application/json" });
      res.end(
        JSON.stringify({
          data: [{ id: "claude-audit", type: "model" }],
          has_more: false,
        }),
      );
      return;
    }
    res.writeHead(200, { "content-type": "application/json" });
    res.end("{}");
  });
});

server.listen(0, "127.0.0.1", () => {
  const port = server.address().port;
  // Print just the port on the first stdout line; the driver reads this.
  console.log(port);
});

// Safety net: if claude never connects, give up after 30 s.
setTimeout(() => {
  console.error("loopback: timeout waiting for /v1/messages");
  process.exit(3);
}, 30000);
