// Actual Chrome UI interaction against the real production widgets/controllers,
// launched only by the isolated test entry, using a unique real browser SQLite DB.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

module.exports = async function verifyIntegratedUi(call, evaluate) {
  const url = `http://127.0.0.1:52842/?integrationApp=true&run=${Date.now()}`;
  const lyrics = '  Browser Unicode 世界 🎵\n\nSecond line!  \n';
  async function text() {
    await evaluate("document.querySelector('flt-semantics-placeholder')?.click()");
    return await evaluate("document.body.innerText+'\\n'+[...document.querySelectorAll('[aria-label]')].map(e=>e.getAttribute('aria-label')).join('\\n')") || '';
  }
  async function waitFor(value) {
    for (let i=0;i<400;i++) { const current = await text(); if(current.includes(value)) return current; await delay(50); }
    throw Error(`UI text missing: ${value}; actual: ${await text()}`);
  }
  async function marker() {
    for(let i=0;i<400;i++) {
      const result = await evaluate("document.documentElement.getAttribute('data-integration')");
      if(result) { const value=JSON.parse(result); assert.notEqual(value.status,'failed',result); return value; }
      await delay(50);
    }
    throw Error('Integrated application bootstrap timed out');
  }
  async function click(label, occurrence = -1) {
    await waitFor(label);
    await delay(300);
    let box;
    for(let attempt=0;attempt<15;attempt++) {
      box=await evaluate(`(() => {
        const label=${JSON.stringify(label)};
        const candidates=[...document.querySelectorAll('flt-semantics,button,[role="button"]')].filter(e=>e.getAttribute('aria-label')?.includes(label) || e.innerText?.trim().includes(label));
        const interactive='[role="button"],[role="checkbox"],[role="radio"],[role="tab"],button';
        const nodes=[...new Set(candidates.map(e=>e.closest(interactive)).filter(Boolean))].filter(e=>{const r=e.getBoundingClientRect();return r.width>0&&r.height>0&&e.getAttribute('aria-disabled')!=='true'&&!e.hasAttribute('disabled');});
        nodes.sort((a,b)=>Number(b.getAttribute('role')==='button')-Number(a.getAttribute('role')==='button') || a.getBoundingClientRect().width*a.getBoundingClientRect().height-b.getBoundingClientRect().width*b.getBoundingClientRect().height);
        const buttons=nodes.filter(e=>e.getAttribute('role')==='button');
        const node=(buttons.length?buttons:nodes).at(${occurrence} < 0 ? 0 : ${occurrence});
        if(!node)return null;
        node.scrollIntoView({block:'nearest'});
        const r=node.getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2};
      })()`);
      if(box && box.y>0 && box.y<990)break;
      await call('Input.dispatchMouseEvent',{type:'mouseWheel',x:210,y:600,deltaX:0,deltaY:450});await delay(100);
    }
    assert.ok(box,`Missing clickable semantics ${label}; actual: ${await text()}`);
    await call('Input.dispatchMouseEvent',{type:'mousePressed',...box,button:'left',clickCount:1});
    await call('Input.dispatchMouseEvent',{type:'mouseReleased',...box,button:'left',clickCount:1});await delay(250);
  }
  async function fill(index,value) {
    const exists=await evaluate(`(() => {const label=${JSON.stringify(index===0?'Title':'Description')};const all=[...document.querySelectorAll('input,textarea')];const e=all.find(e=>e.getAttribute('aria-label')===label)||all.filter(e=>{const r=e.getBoundingClientRect();return r.width>0&&r.height>0;})[${index}];if(!e)return false;e.focus();e.select();return true;})()`);
    assert.ok(exists,`Missing input ${index}`);
    await delay(100);
    await call('Input.dispatchKeyEvent',{type:'keyDown',key:'a',code:'KeyA',windowsVirtualKeyCode:65,modifiers:2});
    await call('Input.dispatchKeyEvent',{type:'keyUp',key:'a',code:'KeyA',windowsVirtualKeyCode:65,modifiers:2});
    await call('Input.dispatchKeyEvent',{type:'keyDown',key:'Backspace',code:'Backspace',windowsVirtualKeyCode:8});
    await call('Input.dispatchKeyEvent',{type:'keyUp',key:'Backspace',code:'Backspace',windowsVirtualKeyCode:8});
    if(value.length)await call('Input.insertText',{text:value});
    await delay(100);
  }
  await call('Emulation.setDeviceMetricsOverride',{width:430,height:1000,deviceScaleFactor:1,mobile:true});
  try {
    await call('Page.navigate',{url}); assert.equal((await marker()).status,'seeded');
    await waitFor('Create playlist'); await click('Create playlist'); await waitFor('Changes are saved');
    await fill(0,'Browser UI playlist'); await fill(1,'Browser UI description'); await click('Save');
    await waitFor('Browser UI playlist'); await click('Browser UI playlist'); await click('Edit');
    await waitFor('Edit playlist'); await fill(0,'Browser UI renamed'); await fill(1,''); await click('Save'); await waitFor('Browser UI renamed');
    await click('Add'); await waitFor('Add songs'); await click('Add Browser integration Alpha'); await click('Add'); await waitFor('Song added.'); await click('Close');
    await click('Library'); await click('Songs'); await waitFor('Browser integration Alpha'); await click('Song actions',0);
    await click('Lyrics & Song Details'); await click('Edit lyrics'); await waitFor('Edit manual lyrics'); await fill(0,lyrics); await click('Save'); await waitFor('Second line!');
    await click('Statistics'); await waitFor('0h 0m 14s 346ms');
    for(const label of ['Week','Month','Year','All Time']) { await click(label); await waitFor('0h 0m 14s 346ms'); }
    await click('Device'); const deviceText=await waitFor('Production pairing and authenticated connections remain unavailable.');assert.ok(!deviceText.includes('Authenticated hardware'));
    await click('Add Music'); await waitFor('Audio URL');
    await call('Page.reload',{ignoreCache:true});await delay(500);
    const restored=await marker(); assert.equal(restored.status,'restored');assert.equal(restored.origin,'http://127.0.0.1:52842');
    assert.equal(restored.lyrics,lyrics);assert.deepEqual(restored.playlists,[{name:'Browser UI renamed',description:null,entries:1}]);assert.equal(restored.hardwareAuthenticated,false);assert.equal(restored.songCount,2);
    await waitFor('Browser UI renamed'); await click('Statistics'); await waitFor('0h 0m 14s 346ms');
    console.log('INTEGRATED UI',JSON.stringify({playlistCreateEditAdd:true,lyricsUnicodeSave:true,sameOriginReload:true,statistics:true,tabs:4,hardwareAuthenticated:false,origin:restored.origin}));
  } catch(error) {
    fs.writeFileSync('build/increment7-ui-failure.html',await evaluate('document.documentElement.outerHTML'));
    fs.writeFileSync('build/increment7-ui-failure.png',Buffer.from((await call('Page.captureScreenshot',{format:'png'})).data,'base64'));
    throw error;
  } finally {
    await call('Page.navigate',{url:url+'&cleanup=true'});await delay(300);assert.equal((await marker()).status,'cleaned');
  }
};
