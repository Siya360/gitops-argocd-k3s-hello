const http = require("http");

const port = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "text/html" });
  res.end(`
    <html>
      <head>
        <title>GitOps Hello</title>
      </head>
      <body>
        <h1>Hello from GitOps</h1>
        <p>This app is deployed by Argo CD onto local K3s running inside Docker.</p>
      </body>
    </html>
  `);
});

server.listen(port, () => {
  console.log(`Hello app listening on port ${port}`);
});
