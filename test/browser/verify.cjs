// No npm dependencies. Builds are prepared by the commands in README.md.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const http = require('node:http');
const {spawn} = require('node:child_process');
const assert = require('node:assert/strict');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

async function serve(root, port) {
  const base = path.resolve(root);
  const server = http.createServer(async (request,response) => {
    const url = new URL(request.url,'http://127.0.0.1');
    if (url.pathname.startsWith('/api/')) {
      let body = '';
      for await (const chunk of request) body += chunk;
      response.setHeader('Content-Type','application/json');
      response.end(JSON.stringify({testOnly:true,body:body ? JSON.parse(body) : null}));
      return;
    }
    const target = path.resolve(base, '.' + decodeURIComponent(url.pathname === '/' ? '/index.html' : url.pathname));
    if (!target.startsWith(base + path.sep) || !fs.existsSync(target) || !fs.statSync(target).isFile()) {
      response.writeHead(404); response.end(); return;
    }
    response.setHeader('Cache-Control','no-store');
    response.setHeader('Content-Type',({'.html':'text/html','.js':'application/javascript',
      '.wasm':'application/wasm','.json':'application/json'})[path.extname(target)] || 'application/octet-stream');
    fs.createReadStream(target).pipe(response);
  });
  await new Promise((resolve,reject) => {server.once('error',reject);server.listen(port,'127.0.0.1',resolve);});
  return server;
}

(async () => {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(),'cta2000-browser-'));
  const servers = [];
  let browser, socket;
  try {
    servers.push(await serve('build/browser-verification',52842));
    servers.push(await serve('build/web',52843));
    const chrome = process.env.CHROME_PATH || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
    browser = spawn(chrome,['--headless=new','--disable-gpu','--no-first-run',
      '--remote-debugging-port=0',`--user-data-dir=${profile}`,'about:blank'],
      {windowsHide:true,stdio:'ignore'});
    let browserError;
    browser.on('error',e => browserError=e);
    const activePort = path.join(profile,'DevToolsActivePort');
    for (let i=0;!fs.existsSync(activePort);i++) {
      if (browserError) throw browserError;
      if (i>100) throw new Error('Chrome did not start');
      await delay(100);
    }
    const port=fs.readFileSync(activePort,'utf8').split('\n')[0];
    const pages=await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
    const page=pages.find(p=>p.type==='page');
    socket=new WebSocket(page.webSocketDebuggerUrl);
    await new Promise((resolve,reject)=>{socket.addEventListener('open',resolve,{once:true});socket.addEventListener('error',reject,{once:true});});
    const pending=new Map();let id=0;
    socket.addEventListener('message',e=>{
      const result=JSON.parse(e.data), callback=pending.get(result.id);
      if(callback){pending.delete(result.id);callback(result);}
    });
    async function call(method,params={}) {
      const messageId=++id;
      const result=await new Promise((resolve,reject)=>{
        const timer=setTimeout(()=>{pending.delete(messageId);reject(new Error(`CDP timeout: ${method}`));},10000);
        pending.set(messageId,r=>{clearTimeout(timer);resolve(r);});
        socket.send(JSON.stringify({id:messageId,method,params}));
      });
      if(result.error)throw new Error(JSON.stringify(result.error));
      return result.result;
    }
    async function evaluate(expression) {
      const result=await call('Runtime.evaluate',{expression,returnByValue:true});
      return result.result?.value;
    }
    async function probe() {
      for(let i=0;i<600;i++) {
        const value=await evaluate("document.documentElement.getAttribute('data-verification')");
        if(value){const result=JSON.parse(value);assert.notEqual(result.status,'failed',value);return result;}
        await delay(100);
      }
      throw new Error('Browser verification timed out');
    }
    const url=`http://127.0.0.1:52842/?run=${Date.now()}`;
    await call('Page.navigate',{url});
    const first=await probe();assert.equal(first.status,'seeded');
    assert.equal(first.controllers,true);assert.equal(first.queueWrap,true);
    console.log('FIRST LOAD',JSON.stringify(first));
    await call('Page.reload',{ignoreCache:true});
    // Wait for navigation to replace the previous DOM before reading markers.
    await delay(500);
    const reload=await probe();assert.equal(reload.status,'restored');
    assert.equal(reload.controllers,true);assert.equal(reload.queueWrap,true);
    assert.equal(reload.origin,first.origin);
    console.log('SAME-ORIGIN RELOAD',JSON.stringify(reload));
    await call('Page.navigate',{url:url+'&cleanup=true'});
    await delay(300);assert.equal((await probe()).status,'cleaned');
    await call('Page.navigate',{url:'http://127.0.0.1:52843/'});
    let appText='';
    for(let i=0;i<600;i++) {
      await evaluate("document.querySelector('flt-semantics-placeholder')?.click()");
      appText=await evaluate('document.body.innerText');
      if(appText?.includes('Your Library'))break;
      await delay(100);
    }
    assert.ok(appText.includes('Your Library'),'Production app did not render Library');
    assert.ok(!appText.includes('could not initialize'),'Production database initialization failed');
    console.log('PRODUCTION APP','Library rendered without initialization error');
  } finally {
    socket?.close();
    if(browser && browser.exitCode===null) {
      const closed=new Promise(resolve=>browser.once('exit',resolve));
      browser.kill();await Promise.race([closed,delay(3000)]);
    }
    for(const server of servers){server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}
    // Leave only this run's browser profile in the OS temp directory if Chrome
    // still holds it; never traverse or delete unrelated user profiles.
    const resolvedProfile=path.resolve(profile);
    if(resolvedProfile.startsWith(path.resolve(os.tmpdir())+path.sep) && path.basename(resolvedProfile).startsWith('cta2000-browser-')) {
      try {fs.rmSync(resolvedProfile,{recursive:true,force:true,maxRetries:3,retryDelay:200});} catch {}
    }
  }
})().catch(error=>{console.error(error);process.exitCode=1;});
