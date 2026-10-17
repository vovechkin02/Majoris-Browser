int main(string[] args){
    if(args.length!=6)return 2;
    string root=args[3],url=args[4];bool restore=args[5]=="restore";
    try{MajorisCef.initialize(root,args[1],args[2]);}catch(Error e){stderr.printf("%s\n",e.message);return 1;}
    var normal=new MajorisCef.View(Path.build_filename(root,"browser"),false,url);
    var app=new MajorisCef.View(Path.build_filename(root,"app"),false,url);
    MajorisCef.View? popup=null;
    var loop=new MainLoop();bool normal_loaded=false,app_loaded=false,started=false,success=false,privacy_applied=false,proxy_applied=false;int phase=0;
    string seed="(async()=>{localStorage.setItem('isolation','yes');await new Promise((resolve,reject)=>{const r=indexedDB.open('isolation',1);r.onupgradeneeded=()=>r.result.createObjectStore('values');r.onsuccess=()=>{const d=r.result;const t=d.transaction('values','readwrite');t.objectStore('values').put('yes','value');t.oncomplete=()=>{d.close();resolve();};};r.onerror=()=>reject(r.error);});const c=await caches.open('isolation');await c.put('/stored',new Response('yes'));await navigator.serviceWorker.register('/worker.js');await navigator.serviceWorker.ready;const probe=await(await fetch('/cache-probe')).text();localStorage.setItem('probe',probe);return 'seeded';})()";
    string retained="(async()=>{const db=await indexedDB.databases();const c=await caches.open('isolation');const item=await c.match('/stored');const registrations=await navigator.serviceWorker.getRegistrations();const probe=await(await fetch('/cache-probe')).text();return localStorage.getItem('isolation')==='yes'&&db.some(x=>x.name==='isolation')&&item&&await item.text()==='yes'&&registrations.length>0&&probe===localStorage.getItem('probe')?'retained':'lost';})()";
    string clean="(async()=>{const db=await indexedDB.databases();const cachesPresent=await caches.keys();const workers=await navigator.serviceWorker.getRegistrations();return localStorage.getItem('isolation')===null&&!db.some(x=>x.name==='isolation')&&!cachesPresent.includes('isolation')&&workers.length===0?'clean':'dirty';})()";
    SourceFunc begin=()=>{if(normal_loaded && app_loaded && !started){started=true;normal.command("privacy:1:1");normal.command("proxy:");if(restore){phase=4;normal.evaluate(clean);}else normal.evaluate(seed);}return Source.REMOVE;};
    normal.event.connect((kind,value)=>{
        if(kind=="privacy-applied")privacy_applied=true;
        if(kind=="proxy-applied")proxy_applied=true;
        if(kind=="operation-error" && (value.contains("setting:")))error("%s",value);
        if(kind=="loading" && value=="0"){normal_loaded=true;begin();}
        if(kind=="evaluation")try{
            var parser=new Json.Parser();parser.load_from_data(value);string result=parser.get_root().get_object().get_object_member("result").get_string_member("value");
            if(phase==0){assert(result=="seeded");phase=1;app.evaluate(seed);}
            else if(phase==4){assert(result=="clean");phase=5;app.evaluate(retained);}
        }catch(Error e){error("%s",e.message);}
        if(kind=="cookie-set"){assert(value=="1");normal.clear_site_cookies(url);}
        if(kind=="cookies-cleared" && phase==2){phase=3;normal.get_cookies("https://unrelated.test/");}
        if(kind=="cookies"){assert(value.contains("other=keep"));normal.clear_site_data(url);}
        if(kind=="operation-complete" && value=="clear-site-data"){phase=4;normal.evaluate(clean);}
        if(kind=="operation-error" && value=="clear-site-data")error("Origin data clearing failed");
    });
    app.event.connect((kind,value)=>{
        if(kind=="loading" && value=="0"){app_loaded=true;begin();}
        if(kind=="evaluation")try{
            var parser=new Json.Parser();parser.load_from_data(value);string result=parser.get_root().get_object().get_object_member("result").get_string_member("value");
            if(phase==1){assert(result=="seeded");phase=2;normal.set_cookie("https://unrelated.test/","other","keep");}
            else if(phase==5){assert(result=="retained");phase=6;app.evaluate("document.getElementById('text').focus();'focused'");}
            else if(phase==6){assert(result=="focused");phase=7;app.focus(true);app.ime("日本語😀",0,true);app.evaluate("new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(()=>resolve(document.getElementById('text').value))))");}
            else if(phase==7){assert(result=="日本語😀");phase=8;app.evaluate("navigator.userAgent+'|'+navigator.userAgentData.brands.map(x=>x.brand+':'+x.version).join(',')");}
            else if(phase==8){assert(result.contains("Majoris/"));assert(result.contains("Chromium:152"));assert(result.contains("Majoris:0"));phase=9;app.command("save-pdf");}
        }catch(Error e){error("%s",e.message);}
        if(kind=="save-pdf" && phase==9){uint8[] bytes=Base64.decode(value);assert(bytes.length>100);assert(((string)bytes).has_prefix("%PDF-"));phase=10;app.command("save-page");}
        if(kind=="save-page" && phase==10){assert(value.contains("MIME-Version:"));assert(value.contains("text/html"));assert(privacy_applied && proxy_applied);phase=11;app.pointer(1,50,120,1,0,0,0);app.pointer(2,50,120,1,0,0,0);}
        if(kind=="closed")loop.quit();
    });
    app.popup.connect((child,background,target,new_window)=>{
        assert(phase==11);popup=child;
        child.event.connect((kind,value)=>{
            if(kind=="loading" && value=="0")child.evaluate("!!window.opener && window.opener.location.origin===location.origin && localStorage.getItem('isolation')==='yes'?'opener-retained':'lost'");
            if(kind=="evaluation")try{var parser=new Json.Parser();parser.load_from_data(value);assert(parser.get_root().get_object().get_object_member("result").get_string_member("value")=="opener-retained");success=true;child.close();normal.close();app.close();}catch(Error e){error("%s",e.message);}
        });
    });
    uint timer=Timeout.add_seconds(35,()=>{stderr.printf("Storage fixture timeout in phase %d (popup: %s)\n",phase,popup!=null?"created":"absent");if(popup!=null)popup.close();normal.close();app.close();loop.quit();return Source.REMOVE;});loop.run();Source.remove(timer);MajorisCef.shutdown();
    stdout.printf("Origin cookies, localStorage, IndexedDB, Cache Storage, service workers, HTTP cache and Unicode: %s\n",success?"PASS":"FAIL");return success?0:1;
}
