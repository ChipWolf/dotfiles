#!/usr/bin/env node
// Generic OpenAI-compatible loopback server for prompt-audit captures.
// Captures the first POST body for /v1/responses or /v1/chat/completions,
// writes it to $CAPTURE_OUT, returns a tiny plausible response, then exits.

import { createServer } from "node:http";
import { writeFileSync } from "node:fs";

const out = process.env.CAPTURE_OUT;
if (!out) {
  console.error("CAPTURE_OUT env var required");
  process.exit(2);
}

let captured = false;

function json(res, status, body) {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(body));
}

function sse(res, events) {
  res.writeHead(200, {
    "content-type": "text/event-stream",
    "cache-control": "no-cache",
    connection: "keep-alive",
  });
  for (const event of events) {
    if (event.event) res.write(`event: ${event.event}\n`);
    res.write(`data: ${JSON.stringify(event.data)}\n\n`);
  }
  res.write("data: [DONE]\n\n");
  res.end();
}

function responsesStream(res) {
  const id = "resp_audit";
  sse(res, [
    {
      event: "response.created",
      data: {
        type: "response.created",
        response: {
          id,
          object: "response",
          created_at: Math.floor(Date.now() / 1000),
          status: "in_progress",
          model: "audit-model",
          output: [],
        },
      },
    },
    {
      event: "response.output_item.added",
      data: {
        type: "response.output_item.added",
        output_index: 0,
        item: { id: "msg_audit", type: "message", status: "in_progress", role: "assistant", content: [] },
      },
    },
    {
      event: "response.content_part.added",
      data: {
        type: "response.content_part.added",
        item_id: "msg_audit",
        output_index: 0,
        content_index: 0,
        part: { type: "output_text", text: "" },
      },
    },
    {
      event: "response.output_text.delta",
      data: {
        type: "response.output_text.delta",
        item_id: "msg_audit",
        output_index: 0,
        content_index: 0,
        delta: "ok",
      },
    },
    {
      event: "response.output_text.done",
      data: {
        type: "response.output_text.done",
        item_id: "msg_audit",
        output_index: 0,
        content_index: 0,
        text: "ok",
      },
    },
    {
      event: "response.completed",
      data: {
        type: "response.completed",
        response: {
          id,
          object: "response",
          created_at: Math.floor(Date.now() / 1000),
          status: "completed",
          model: "audit-model",
          output: [
            {
              id: "msg_audit",
              type: "message",
              status: "completed",
              role: "assistant",
              content: [{ type: "output_text", text: "ok", annotations: [] }],
            },
          ],
          usage: { input_tokens: 0, output_tokens: 1, total_tokens: 1 },
        },
      },
    },
  ]);
}

function chatCompletionsStream(res) {
  sse(res, [
    {
      data: {
        id: "chatcmpl_audit",
        object: "chat.completion.chunk",
        created: Math.floor(Date.now() / 1000),
        model: "audit-model",
        choices: [{ index: 0, delta: { role: "assistant", content: "ok" }, finish_reason: null }],
      },
    },
    {
      data: {
        id: "chatcmpl_audit",
        object: "chat.completion.chunk",
        created: Math.floor(Date.now() / 1000),
        model: "audit-model",
        choices: [{ index: 0, delta: {}, finish_reason: "stop" }],
      },
    },
  ]);
}

const server = createServer((req, res) => {
  let body = "";
  req.setEncoding("utf8");
  req.on("data", (chunk) => (body += chunk));
  req.on("end", () => {
    const url = req.url || "";
    console.error(`loopback: ${req.method} ${url}`);

    if (req.method === "GET" && (url.includes("/v1/models") || url.endsWith("/models"))) {
      json(res, 200, { object: "list", data: [{ id: "audit-model", object: "model" }] });
      return;
    }

    if (req.method === "POST" && (url.includes("/responses") || url.includes("/chat/completions"))) {
      const isTitleRequest = /title generator|Generate a title for this conversation/i.test(body);
      if (!captured && !(process.env.SKIP_TITLE_REQUEST === "1" && isTitleRequest)) {
        captured = true;
        writeFileSync(out, body);
        if (url.includes("/responses")) {
          responsesStream(res);
        } else {
          chatCompletionsStream(res);
        }
        setTimeout(() => {
          server.close();
          process.exit(0);
        }, 100);
        return;
      }
      if (url.includes("/responses")) {
        responsesStream(res);
      } else {
        chatCompletionsStream(res);
      }
      return;
    }

    json(res, 200, {});
  });
});

server.listen(0, "127.0.0.1", () => {
  console.log(server.address().port);
});

setTimeout(() => {
  console.error("loopback: timeout waiting for provider request");
  process.exit(3);
}, 45000);
