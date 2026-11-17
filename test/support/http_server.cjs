// Development HTTP fixture only. This is not a Radxa simulator or app backend.
const http = require('node:http');
const port = Number(process.env.MOCK_PORT || 8765);
const origin = process.env.MOCK_ORIGIN || 'http://localhost:52841';
const server = http.createServer(async (request, response) => {
  response.setHeader('Access-Control-Allow-Origin', origin);
  response.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  response.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  response.setHeader('Content-Type', 'application/json');
  if (request.method === 'OPTIONS') { response.writeHead(204); response.end(); return; }
  if (request.method === 'GET' && request.url === '/health') {
    response.end(JSON.stringify({testOnly:true,reachable:true,hardwareAuthenticated:false}));
    return;
  }
  if (request.method === 'POST' && request.url === '/echo') {
    try {
      let body = '';
      for await (const chunk of request) {
        body += chunk;
        if (body.length > 65536) { response.writeHead(413); response.end('{}'); return; }
      }
      response.end(JSON.stringify({testOnly:true,body:JSON.parse(body)}));
    } catch { response.writeHead(400); response.end('{"testOnly":true,"error":"Invalid JSON"}'); }
    return;
  }
  response.writeHead(404);
  response.end('{"testOnly":true,"error":"Unknown test endpoint"}');
});
server.listen(port,'127.0.0.1',()=>console.log(`Test-only HTTP server: http://127.0.0.1:${port}; allowed browser origin: ${origin}`));
