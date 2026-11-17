// Real, unchanged owner WAVs, real just_audio/Chrome engine and controller UI.
// No synthetic engine, generated audio, downloads, or Radxa operations.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const http=require('node:http'),assert=require('node:assert/strict');
const {spawn}=require('node:child_process');
const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function serve(root,port) {
  const base=path.resolve(root);
  const server=http.createServer((request,response)=>{
    const name=new URL(request.url,'http://127.0.0.1').pathname;
    const raw=path.resolve(base,'.'+(name==='/'?'/index.html':name));
    // Flutter's release asset filenames can retain percent escapes on disk.
    const file=fs.existsSync(raw)?raw:path.resolve(base,'.'+decodeURIComponent(name==='/'?'/index.html':name));
    if(!file.startsWith(base+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile()){response.writeHead(404);response.end();return;}
    const size=fs.statSync(file).size;
    response.setHeader('Content-Type',({'.wav':'audio/wav','.js':'application/javascript','.json':'application/json','.html':'text/html','.wasm':'application/wasm'})[path.extname(file)]||'application/octet-stream');
    response.setHeader('Cache-Control','no-store');response.setHeader('Accept-Ranges','bytes');
    const range=request.headers.range?.match(/^bytes=(\d+)-(\d*)$/);
    let start=0,end=size-1;
    if(range){start=Number(range[1]);end=range[2]?Math.min(Number(range[2]),size-1):size-1;if(start>=size||end<start){response.writeHead(416,{'Content-Range':`bytes */${size}`});response.end();return;}response.statusCode=206;response.setHeader('Content-Range',`bytes ${start}-${end}/${size}`);}
    response.setHeader('Content-Length',end-start+1);
    if(request.method==='HEAD'){response.end();return;}
    fs.createReadStream(file,{start,end}).pipe(response);
  });
  await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(port,'127.0.0.1',resolve);});return server;
}
(async()=>{
  const servers=[],profile=fs.mkdtempSync(path.join(os.tmpdir(),'cta2000-wav-'));
  let browser,socket;
  try{
    servers.push(await serve('build/test-music',52900));servers.push(await serve('build/wav-playback',52901));servers.push(await serve('build/web',52902));
    browser=spawn(process.env.CHROME_PATH||'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',['--headless=new','--disable-gpu','--no-first-run','--remote-debugging-port=0',`--user-data-dir=${profile}`,'about:blank'],{windowsHide:true,stdio:'ignore'});
    let launchError;browser.on('error',e=>launchError=e);
    const active=path.join(profile,'DevToolsActivePort');
    for(let i=0;!fs.existsSync(active);i++){if(launchError)throw launchError;if(i>100)throw Error('Chrome did not start');await delay(100);}
    const port=fs.readFileSync(active,'utf8').split('\n')[0],pages=await(await fetch(`http://127.0.0.1:${port}/json/list`)).json();
    socket=new WebSocket(pages.find(p=>p.type==='page').webSocketDebuggerUrl);await new Promise((r,j)=>{socket.addEventListener('open',r,{once:true});socket.addEventListener('error',j,{once:true});});
    const pending=new Map();let sequence=0;
    socket.addEventListener('message',event=>{const value=JSON.parse(event.data),callback=pending.get(value.id);if(callback){pending.delete(value.id);callback(value);}});
    async function call(method,params={}){const id=++sequence;const result=await new Promise((r,j)=>{const timer=setTimeout(()=>{pending.delete(id);j(Error(`CDP timeout: ${method}`));},15000);pending.set(id,value=>{clearTimeout(timer);r(value);});socket.send(JSON.stringify({id,method,params}));});if(result.error)throw Error(JSON.stringify(result.error));return result.result;}
    async function evaluate(expression){return(await call('Runtime.evaluate',{expression,returnByValue:true})).result?.value;}
    async function text(){await evaluate("document.querySelector('flt-semantics-placeholder')?.click()");return await evaluate("document.body.innerText+'\\n'+[...document.querySelectorAll('[aria-label]')].map(e=>e.getAttribute('aria-label')).join('\\n')")||'';}
    async function waitFor(check,label){for(let i=0;i<1200;i++){const value=await text();if(check(value))return value;await delay(50);}throw Error(`Timed out: ${label}; actual: ${await text()}`);}
    async function click(label,occurrence=0){await waitFor(t=>t.includes(label),label);await delay(150);let box;
      for(let i=0;i<40;i++){
        box=await evaluate(`(()=>{const label=${JSON.stringify(label)},selector='[role="button"],[role="tab"],[role="radio"],[role="checkbox"],button';const nodes=[...new Set([...document.querySelectorAll('flt-semantics,button')].filter(e=>e.getAttribute('aria-label')?.includes(label)||e.innerText?.trim().includes(label)).map(e=>e.closest(selector)).filter(Boolean))].filter(e=>{const r=e.getBoundingClientRect();return r.width>0&&r.height>0&&e.getAttribute('aria-disabled')!=='true'&&!e.hasAttribute('disabled');});nodes.sort((a,b)=>Number(b.getAttribute('aria-label')===label||b.innerText?.trim()===label)-Number(a.getAttribute('aria-label')===label||a.innerText?.trim()===label)||a.getBoundingClientRect().width*a.getBoundingClientRect().height-b.getBoundingClientRect().width*b.getBoundingClientRect().height);const e=nodes[${occurrence}];if(!e)return null;e.scrollIntoView({block:'nearest'});const r=e.getBoundingClientRect();return{x:r.x+r.width/2,y:r.y+r.height/2};})()`);
        if(box&&box.y>0&&box.y<1000)break;await call('Input.dispatchMouseEvent',{type:'mouseWheel',x:210,y:600,deltaX:0,deltaY:400});await delay(100);
      }
      assert.ok(box,`Missing enabled control ${label}`);await call('Input.dispatchMouseEvent',{type:'mousePressed',...box,button:'left',clickCount:1});await call('Input.dispatchMouseEvent',{type:'mouseReleased',...box,button:'left',clickCount:1});await delay(200);
    }
    async function seek(seconds){
      assert.ok(await evaluate("(()=>{const e=document.querySelector('input,textarea');if(!e)return false;e.focus();e.select();return true;})()"));await delay(100);
      await call('Input.dispatchKeyEvent',{type:'keyDown',key:'a',code:'KeyA',windowsVirtualKeyCode:65,modifiers:2});await call('Input.dispatchKeyEvent',{type:'keyUp',key:'a',code:'KeyA',windowsVirtualKeyCode:65,modifiers:2});
      await call('Input.insertText',{text:String(seconds)});await click('Seek');
    }
    async function openMiniPlayer(){
      // Tap the bar beside its transport toggle, away from scrolling links/snackbars.
      const box=await evaluate("(()=>{const button=[...document.querySelectorAll('[role=button]')].find(e=>e.getAttribute('aria-label')==='Pause'||e.innerText?.trim()==='Pause');if(!button)return null;const r=button.getBoundingClientRect();return{x:r.x-100,y:r.y+r.height/2};})()");
      assert.ok(box,'Visible mini-player transport toggle');
      await call('Input.dispatchMouseEvent',{type:'mousePressed',...box,button:'left',clickCount:1});
      await call('Input.dispatchMouseEvent',{type:'mouseReleased',...box,button:'left',clickCount:1});
      await waitFor(t=>t.includes('YOUR MUSIC'),'mini-player opens Now Playing');
    }
    function state(value){return{song:value.match(/Song:\s*(.*?)\s+Queue index:/s)?.[1],index:Number(value.match(/Queue index: (\d+)/)?.[1]),position:Number(value.match(/Position: (\d+) ms/)?.[1]),duration:Number(value.match(/Duration: (\d+) ms/)?.[1])};}
    await call('Emulation.setDeviceMetricsOverride',{width:430,height:1000,deviceScaleFactor:1,mobile:true});
    await call('Page.navigate',{url:'http://127.0.0.1:52902/'});await waitFor(t=>t.includes('No saved songs or playlists'),'normal fresh database empty');console.log('NORMAL APP No automatic fixture registration without development flag.');
    const testUrl=process.env.WAV_DEBUG_URL||'http://127.0.0.1:52900/';
    assert.match(testUrl,/^http:\/\/(localhost|127\.0\.0\.1):\d+\/$/);
    await call('Page.navigate',{url:testUrl});let library=await waitFor(t=>t.includes('Track 6'),'all six actual test songs visible immediately, without selecting a category');
    assert.ok(library.includes('Select a song to play'),'Available WAVs should not be labeled as awaiting an MP3');
    fs.writeFileSync('build/debug-music-library.png',Buffer.from((await call('Page.captureScreenshot',{format:'png'})).data,'base64'));
    for(let i=1;i<=6;i++)assert.ok(library.includes(`Track ${i}`));assert.ok(library.includes('WAV'));await call('Page.reload',{ignoreCache:true});await delay(500);library=await waitFor(t=>t.includes('Track 6'),'persisted six songs visible immediately after reload');console.log('TEST LIBRARY Six real WAV songs visible immediately and restored at the same origin.',testUrl);
    await click('Track 1');await waitFor(t=>t.includes('Playing locally'),'normal app source tap autoplays WAV in library');
    await openMiniPlayer(); await waitFor(t=>t.includes('0:01'),'normal app actual playback progress');await click('Pause');await waitFor(t=>t.includes('Paused · Local audio'),'normal app actual WAV paused');console.log('MAIN APP Actual WAV selection, advancing progress and Pause passed.');
    await click('Back'); await click('Track 5'); await waitFor(t=>t.includes('Playing locally'),'Track 5 autoplays in library');
    await openMiniPlayer();
    await waitFor(t=>t.includes('0:02'),'Track 5 actual audio progress before queue edits');
    function mainPosition(value){const match=value.match(/(?:^|\n)(\d+):(\d\d)(?:\n|$)/);return match?Number(match[1])*60+Number(match[2]):0;}
    const before=mainPosition(await text()); assert.ok(before>=2);
    await click('Back');
    // Returning restores the scrolled Track 5 list. Bring source rows 1/2 into view.
    await call('Input.dispatchMouseEvent',{type:'mouseWheel',x:210,y:400,deltaX:0,deltaY:-5000}); await delay(350);
    await click('Song actions'); await click('Add to Queue');
    await click('Song actions',1);
    await click('Add to Queue');
    await openMiniPlayer();
    const after=await waitFor(t=>t.includes('Playing locally')&&t.includes('Track 5'),'Track 5 still playing after queue edits');
    assert.ok(mainPosition(after)>=before,'Queue edits did not reset actual WAV progress');
    for(const track of [1,2,6]) { await click('Next'); await waitFor(t=>t.includes(`Track ${track}`)&&t.includes('Playing locally'),`FIFO next Track ${track}`); }
    await click('Pause'); console.log('MAIN APP REAL WAV QUEUE Track 5 → 1 → 2 → 6; current audio source and position preserved during edits.');
    await call('Page.navigate',{url:'http://127.0.0.1:52901/'});await waitFor(t=>t.includes('Manual audio verification required'),'WAV harness available');await click('Load queue');
    let current=state(await waitFor(t=>t.includes('Processing: ready')&&t.includes('Song: Track 1')&&state(t).duration>0,'first WAV decoded with engine duration'));
    const expected=[238146,241560,278080,211000,324306,240880],results=[];
    console.log('FIRST WAV ENGINE STATE',JSON.stringify(current));
    assert.ok(Math.abs(current.duration-expected[0])<=2,`Actual first WAV duration ${current.duration} ms versus RIFF data ${expected[0]} ms`);results.push(current);
    await click('Play');await waitFor(t=>t.includes('Playing and ready: true')&&state(t).position>300,'real WAV position advances');
    await click('Pause');let paused=state(await waitFor(t=>t.includes('Playing and ready: false'),'pause'));await delay(400);assert.ok(Math.abs(state(await text()).position-paused.position)<100,'Paused position continued advancing');
    await seek(12);await waitFor(t=>Math.abs(state(t).position-12000)<200,'real seek');await click('Resume');await waitFor(t=>t.includes('Playing and ready: true')&&state(t).position>12200,'resume');
    await click('Next');await waitFor(t=>t.includes('Song: Track 2')&&t.includes('Playing and ready: true'),'next preserves playback');await click('Previous');await waitFor(t=>t.includes('Song: Track 1')&&t.includes('Playing and ready: true'),'previous preserves playback');
    for(let i=1;i<6;i++){await click('Next');const value=await waitFor(t=>t.includes(`Song: Track ${i+1}`)&&t.includes('Processing: ready')&&t.includes('Playing and ready: true'),`WAV ${i+1} decoded`);current=state(value);assert.equal(current.index,i);assert.ok(Math.abs(current.duration-expected[i])<=2,`Unexpected duration ${current.duration}`);results.push(current);}
    await seek(expected[5]/1000-.4);await waitFor(t=>t.includes('Song: Track 1')&&t.includes('Queue index: 0')&&t.includes('Playing and ready: true'),'natural completion advances and wraps');
    await click('Stop');await waitFor(t=>t.includes('Processing: idle')&&t.includes('Playing and ready: false'),'stop');
    const result={tracks:results,playPauseResume:true,advancingPosition:true,seek:true,nextPrevious:true,naturalCompletionWrap:true,stop:true,realMp3:'Not Tested - Awaiting MP3 File',audibility:'Not verified by headless Chrome'};
    fs.writeFileSync('build/wav-playback-verification.json',JSON.stringify(result,null,2));console.log('REAL WAV PLAYBACK',JSON.stringify(result));
  }finally{
    socket?.close();if(browser&&browser.exitCode===null){const stopped=new Promise(r=>browser.once('exit',r));browser.kill();await Promise.race([stopped,delay(3000)]);}
    for(const server of servers){server.closeAllConnections();await new Promise(r=>server.close(r));}
    const resolved=path.resolve(profile);if(resolved.startsWith(path.resolve(os.tmpdir())+path.sep)&&path.basename(resolved).startsWith('cta2000-wav-')){try{fs.rmSync(resolved,{recursive:true,force:true,maxRetries:3,retryDelay:200});}catch{}}
  }
})().catch(error=>{console.error(error);process.exitCode=1;});
