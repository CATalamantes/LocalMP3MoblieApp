// Real rendered-screen capture. No npm dependencies, device calls or audio.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const http = require('node:http');
const crypto = require('node:crypto');
const {spawn} = require('node:child_process');
const assert = require('node:assert/strict');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const screens = [
  ['library','Your Library','library_persona_5_black_red_screen.png'],
  ['playlist','Playlist Details','playlist_details_persona_5_black_red_screen.png'],
  ['nowPlaying','Now Playing','now_playing_midnight_crimson_screen.png'],
  ['songDetails','Lyrics & Song Details','lyrics_song_details_screen.png'],
  ['lyrics','Fullscreen Lyrics','fullscreen_lyrics_screen.png'],
  ['addMusic','Add Music','add_music_persona_5_black_red_screen.png'],
  ['record','Record Audio','record_audio_vinyl_cd_digitization_screen.png'],
  ['saveRecording','Save to Library','save_recording_track_info_screen.png'],
  ['device','Device','device_main_settings_screen.png'],
  ['connections','Connections','connections_screen.png'],
  ['sync','Music Sync','music_sync_screen.png'],
  ['storage','Storage','storage_screen.png'],
  ['files','File Manager','file_manager_screen.png'],
  ['bluetoothAudio','Bluetooth Audio','bluetooth_audio_screen.png'],
  ['batteryDisplay','Battery & Display','battery_display_screen.png'],
  ['aboutDevice','About Device','about_device_screen.png'],
  ['statistics','Listening Statistics','listening_statistics_screen.png'],
];
const route = {library:'library',playlist:'playlist',nowPlaying:'now-playing',songDetails:'song-details',
  lyrics:'lyrics',addMusic:'add-music',record:'record',saveRecording:'save-recording',device:'device',
  connections:'connections',sync:'sync',storage:'storage',files:'files',bluetoothAudio:'bluetooth-audio',
  batteryDisplay:'battery-display',aboutDevice:'about-device',statistics:'statistics'};
async function serve(root, port) {
  const base = path.resolve(root);
  const server = http.createServer((request,response) => {
    const pathname = new URL(request.url,'http://127.0.0.1').pathname;
    const file = path.resolve(base,'.' + decodeURIComponent(pathname === '/' ? '/index.html' : pathname));
    if (!file.startsWith(base+path.sep) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
      response.writeHead(404); response.end(); return;
    }
    response.setHeader('Cache-Control','no-store');
    response.setHeader('Content-Type',({'.html':'text/html','.js':'application/javascript',
      '.json':'application/json','.wasm':'application/wasm'})[path.extname(file)] || 'application/octet-stream');
    fs.createReadStream(file).pipe(response);
  });
  await new Promise((resolve,reject) => {server.once('error',reject);server.listen(port,'127.0.0.1',resolve);});
  return server;
}
(async () => {
  const output = path.resolve('build/increment6-visual'); fs.mkdirSync(output,{recursive:true});
  const profile = fs.mkdtempSync(path.join(os.tmpdir(),'cta2000-visual-'));
  const servers = []; let browser, socket;
  const manifest = {viewport:{width:390,height:844,textScale:1},screens:[]};
  try {
    servers.push(await serve('build/frontend-preview',52845));
    servers.push(await serve('build/web',52846));
    browser = spawn(process.env.CHROME_PATH || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
      ['--headless=new','--disable-gpu','--no-first-run','--remote-debugging-port=0',`--user-data-dir=${profile}`,'about:blank'],
      {windowsHide:true,stdio:'ignore'});
    let launchError; browser.on('error',error=>launchError=error);
    const active = path.join(profile,'DevToolsActivePort');
    for(let i=0;!fs.existsSync(active);i++) {if(launchError)throw launchError;if(i>100)throw Error('Chrome did not launch');await delay(100);}
    const port = fs.readFileSync(active,'utf8').split('\n')[0];
    const pages = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
    socket = new WebSocket(pages.find(p=>p.type==='page').webSocketDebuggerUrl);
    await new Promise((resolve,reject)=>{socket.addEventListener('open',resolve,{once:true});socket.addEventListener('error',reject,{once:true});});
    const pending = new Map(); let id=0;
    socket.addEventListener('message',event=>{const result=JSON.parse(event.data);const callback=pending.get(result.id);
      if(callback){pending.delete(result.id);callback(result);}});
    async function call(method,params={}) {
      const requestId=++id;
      const result=await new Promise((resolve,reject)=>{const timer=setTimeout(()=>{pending.delete(requestId);reject(Error(`CDP timeout ${method}`));},15000);
        pending.set(requestId,value=>{clearTimeout(timer);resolve(value);});socket.send(JSON.stringify({id:requestId,method,params}));});
      if(result.error)throw Error(JSON.stringify(result.error));return result.result;
    }
    async function evaluate(expression) {
      const value=await call('Runtime.evaluate',{expression,returnByValue:true});
      return value.result?.value;
    }
    await call('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:true});
    for (const variant of ['production','preview']) {
      for (const [screen,title,wireframe] of screens) {
        await evaluate("document.documentElement.setAttribute('data-old-visual','true')");
        const url=variant==='preview' ? `http://127.0.0.1:52845/?screen=${screen}&state=ready`
          : `http://127.0.0.1:52846/?capture=${screen}#/${route[screen]}`;
        await call('Page.navigate',{url});
        let text='';
        for(let i=0;i<600;i++) {
          await evaluate("document.querySelector('flt-semantics-placeholder')?.click()");
          const old=await evaluate("document.documentElement.hasAttribute('data-old-visual')");
          text=await evaluate('document.body.innerText');
          const pageTitle=await evaluate('document.title');
          if(!old && text?.includes(title) && (variant==='production' || pageTitle==='CTA2000 Design Preview'))break;
          await delay(100);
        }
        assert.ok(text?.includes(title),`Missing ${variant} ${screen}`);
        if(variant==='preview')assert.equal(await evaluate('document.title'),'CTA2000 Design Preview');
        assert.ok(!text.includes('could not initialize'),`Initialization error ${screen}`);
        if(variant==='production')assert.ok(!text.includes('Sample Artist') && !text.includes('DESIGN-SAMPLE'));
        const entry={variant,screen,wireframe,files:[]}; let previous;
        for(let position=0;position<8;position++) {
          await delay(180);
          const png=Buffer.from((await call('Page.captureScreenshot',{format:'png'})).data,'base64');
          const hash=crypto.createHash('sha256').update(png).digest('hex');if(hash===previous)break;previous=hash;
          const name=`${variant}-${screen}-${position}.png`;fs.writeFileSync(path.join(output,name),png);entry.files.push(name);
          await call('Input.dispatchMouseEvent',{type:'mouseWheel',x:195,y:400,deltaX:0,deltaY:500});
        }
        manifest.screens.push(entry); console.log('CAPTURED',variant,screen,entry.files.length);
      }
    }
    assert.equal(manifest.screens.length,34);
    fs.writeFileSync(path.join(output,'manifest.json'),JSON.stringify(manifest,null,2));
    fs.writeFileSync(path.join(output,'index.html'),'<!doctype html><meta charset="utf-8"><title>Increment 6 visual review</title>'+
      '<style>body{background:#101722;color:#f5f6fa;font:14px sans-serif}section{display:flex;gap:10px;flex-wrap:wrap}img{width:195px}article{margin-bottom:30px}h2{font-size:18px}</style>'+
      manifest.screens.map(entry=>`<article><h2>${entry.variant} — ${entry.screen}</h2><p>${entry.wireframe}</p><section>`+
        entry.files.map(name=>`<a href="${name}"><img src="${name}" alt="${name}"></a>`).join('')+'</section></article>').join(''));
    console.log('VISUAL CAPTURE PASSED: 17 production screens + 17 isolated previews; human image inspection still required.');
  } finally {
    socket?.close();
    if(browser && browser.exitCode===null){const closed=new Promise(resolve=>browser.once('exit',resolve));browser.kill();await Promise.race([closed,delay(3000)]);}
    for(const server of servers){server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}
    const resolved=path.resolve(profile);
    if(resolved.startsWith(path.resolve(os.tmpdir())+path.sep) && path.basename(resolved).startsWith('cta2000-visual-')) {
      try{fs.rmSync(resolved,{recursive:true,force:true,maxRetries:3,retryDelay:200});}catch{}
    }
  }
})().catch(error=>{console.error(error);process.exitCode=1;});
