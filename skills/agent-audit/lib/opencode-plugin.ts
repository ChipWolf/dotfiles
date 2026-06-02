// OpenCode plugin: hook experimental.chat.system.transform, dump the assembled
// system prompt to $OC_AUDIT_OUT, and exit before any model call.
//
// Loaded via OPENCODE_CONFIG_CONTENT='{"plugin":["file:///abs/path/to/this.ts"]}'.
// The hook fires twice per `opencode run`: once for the hidden title-generator
// subtask, once for the build agent. We skip the title call and keep the
// build-agent capture.

import type { Plugin } from "@opencode-ai/plugin";
import { writeFileSync } from "node:fs";

const OUT = process.env.OC_AUDIT_OUT || "/tmp/oc-audit-prompt.json";

export default (async () => {
  return {
    "experimental.chat.system.transform": async (input: any, output: any) => {
      const sys: string[] = output.system || [];
      const firstHead = (sys[0] || "").slice(0, 80);
      const capture = {
        capturedAt: new Date().toISOString(),
        sessionID: input.sessionID,
        modelID: input.model?.id,
        pieces: sys.length,
        pieceLengths: sys.map((s: string) => s.length),
        totalChars: sys.reduce((a: number, s: string) => a + s.length, 0),
        firstHead,
        system: sys,
      };
      if (/title generator/i.test(firstHead)) {
        return; // wait for the build-agent call
      }
      writeFileSync(OUT, JSON.stringify(capture, null, 2));
      process.exit(0);
    },
  };
}) satisfies Plugin;
