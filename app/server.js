const http = require("http");
const url = require("url");

const port = process.env.PORT || 3000;
const envName = process.env.ENV_NAME || "unknown";
const envRole = process.env.ENV_ROLE || "unknown";
const greetingMessage = process.env.GREETING_MESSAGE || "Hello";
const dependencyUrl = process.env.DEPENDENCY_URL || "";

function dependencyCheck(callback) {
  if (!dependencyUrl) {
    return callback(null, { ok: true, status: "no-dependency" });
  }
  const parsed = url.parse(dependencyUrl + "/healthz");
  const proto = parsed.protocol === "https:" ? require("https") : require("http");
  const req = proto.get(
    { hostname: parsed.hostname, port: parsed.port, path: parsed.path, timeout: 3000 },
    (res) => {
      let data = "";
      res.on("data", (chunk) => { data += chunk; });
      res.on("end", () => {
        callback(null, { ok: res.statusCode === 200, statusCode: res.statusCode, body: data });
      });
    }
  );
  req.on("error", (err) => {
    callback(null, { ok: false, error: err.message });
  });
  req.on("timeout", () => {
    req.destroy();
    callback(null, { ok: false, error: "timeout" });
  });
}

const server = http.createServer((req, res) => {
  if (req.url === "/healthz") {
    res.writeHead(200, { "Content-Type": "text/plain" });
    res.end("ok");
    return;
  }

  if (req.url === "/readyz") {
    if (envName === "env-d") {
      res.writeHead(200, { "Content-Type": "text/plain" });
      res.end("ready");
      return;
    }
    dependencyCheck((err, result) => {
      if (result && result.ok) {
        res.writeHead(200, { "Content-Type": "text/plain" });
        res.end("ready");
      } else {
        res.writeHead(503, { "Content-Type": "text/plain" });
        res.end("not ready: dependency unreachable");
      }
    });
    return;
  }

  if (req.url === "/dependency-check") {
    dependencyCheck((err, result) => {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({
        dependencyUrl: dependencyUrl || null,
        reachable: result ? result.ok : false,
        details: result || null
      }, null, 2));
    });
    return;
  }

  // Default page
  let extraInfo = "";
  if (envName === "env-d") {
    extraInfo = "<p><strong>I am the shared dependency used by A/B/C and customer UAT.</strong></p>";
  } else if (dependencyUrl) {
    extraInfo = `<p>Dependency URL: <code>${dependencyUrl}</code></p>`;
  }

  res.writeHead(200, { "Content-Type": "text/html" });
  res.end(`
    <html>
      <head><title>${envName} — GitOps BancX Demo</title></head>
      <body>
        <h1>${greetingMessage}</h1>
        <p>Environment: <strong>${envName}</strong></p>
        <p>Role: <strong>${envRole}</strong></p>
        ${extraInfo}
      </body>
    </html>
  `);
});

server.listen(port, () => {
  console.log(`${envName} (${envRole}) listening on port ${port}`);
});
