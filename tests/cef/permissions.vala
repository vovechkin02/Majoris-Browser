using MajorisBrowser;
int main(string[] args){
    try{
        string origin=UrlResolver.origin(args[4]),path=Path.build_filename(args[3],"permissions.db");{var store=new Store(path);store.permission("browser",origin,"notifications",1);store.permission("app",origin,"notifications",2);}
        var worker=new StoreWorker(path);var browser_policy=new PermissionService(worker,"browser");var app_policy=new PermissionService(worker,"app");MajorisCef.initialize(args[3],args[1],args[2]);
        var browser=new MajorisCef.View.with_permissions(Path.build_filename(args[3],"browser"),false,args[4],"",browser_policy.serialized());var app=new MajorisCef.View.with_permissions(Path.build_filename(args[3],"app"),false,args[4],"",app_policy.serialized());browser_policy.attach(browser);app_policy.attach(app);
        var loop=new MainLoop();int phase=0;bool browser_loaded=false,app_loaded=false,success=false;
        SourceFunc start=()=>{if(browser_loaded && app_loaded && phase==0){phase=1;browser.evaluate("Notification.permission");}return Source.REMOVE;};
        browser.event.connect((kind,text)=>{
            if(kind=="loading" && text=="0"){browser_loaded=true;start();}
            if(kind=="permissions-applied" && phase==3)browser.evaluate("new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(()=>resolve(Notification.permission))))");
            if(kind=="evaluation"){var p=new Json.Parser();try{p.load_from_data(text);string value=p.get_root().get_object().get_object_member("result").get_string_member("value");if(phase==1){assert(value=="granted");phase=2;app.evaluate("Notification.permission");}else if(phase==3){assert(value=="denied");phase=4;browser_policy.reset("browser",origin);}else if(phase==5){assert(value=="default");success=true;browser.close();app.close();}}catch(Error e){error("%s",e.message);}}
            if(kind=="permissions-applied" && phase==4){phase=5;browser.evaluate("new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(()=>resolve(Notification.permission))))");}
        });
        app.event.connect((kind,text)=>{if(kind=="loading" && text=="0"){app_loaded=true;start();}if(kind=="evaluation")try{var p=new Json.Parser();p.load_from_data(text);assert(p.get_root().get_object().get_object_member("result").get_string_member("value")=="denied");phase=3;browser_policy.remember("browser",origin+"/path",{"notifications"},2);}catch(Error e){error("%s",e.message);}if(kind=="closed")loop.quit();});
        uint timer=Timeout.add_seconds(20,()=>{browser.close();app.close();loop.quit();return Source.REMOVE;});loop.run();Source.remove(timer);MajorisCef.shutdown();worker.stop();assert(success);stdout.printf("Persisted permission isolation, live revocation and reset in Chromium: PASS\n");
    }catch(Error e){error("%s",e.message);}return 0;
}
