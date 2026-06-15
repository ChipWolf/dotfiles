// pi extension: override the built-in "anthropic" provider's baseUrl so that
// pi sends its first-turn Anthropic /v1/messages request to the audit loopback
// server instead of api.anthropic.com.
//
// Usage: set PI_AUDIT_LOOPBACK_PORT to the loopback port before launching pi.
// audit.sh writes this file to the throwaway PI_CODING_AGENT_DIR and lists it
// in settings.json extensions so pi loads it on startup.
export default function (pi) {
	const port = process.env.PI_AUDIT_LOOPBACK_PORT;
	if (!port) throw new Error("PI_AUDIT_LOOPBACK_PORT env var required");
	pi.registerProvider("anthropic", {
		baseUrl: "http://127.0.0.1:" + port,
	});
}
