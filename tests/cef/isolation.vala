// Runs the real CEF cookie stores, not a filesystem simulation.
int main (string[] args) {
    if (args.length < 3) return 2;
    if(args.length>4 && args[4]=="clear"){
        try{MajorisCef.clear_profile(args[3]);return 0;}catch(Error e){stderr.printf("%s\n",e.message);return 1;}
    }
    MainLoop loop=new MainLoop();int phase=0;int ready=0;bool success=false;
    string root;
    bool restore=args.length>4 && args[4]=="restore";
    try { root=args.length>3?args[3]:DirUtils.make_tmp("majoris-cef-test-XXXXXX");MajorisCef.initialize(root,args[1],args[2]); }
    catch(Error e){stderr.printf("%s\n",e.message);return 1;}
    bool busy=false;
    try{MajorisCef.clear_profile(root);}catch(Error e){busy=true;}
    assert(busy);
    var normal=new MajorisCef.View(Path.build_filename(root,"browser"),args.length>4 && args[4]=="private","about:blank");
    var app=new MajorisCef.View(Path.build_filename(root,"fixture"),false,"about:blank");
    message("CEF test: views requested");
    SourceFunc begin=()=>{ready++;if(ready==2){if(restore)normal.get_cookies("https://fixture.test/");else{normal.set_cookie("https://fixture.test/","normal","yes");app.set_cookie("https://fixture.test/","app","yes");}}return Source.REMOVE;};
    int set=0;
    normal.event.connect((kind,value)=>{
        if(kind=="ready")begin();
        if(kind=="cookie-set"){assert(value=="1");set++;if(set==2)normal.clear_cookies();}
        if(kind=="cookies-cleared"){assert(value=="1");normal.get_cookies("https://fixture.test/");}
        if(kind=="cookies"){assert(value=="");phase=1;app.get_cookies("https://fixture.test/");}
    });
    app.event.connect((kind,value)=>{
        if(kind=="ready")begin();
        if(kind=="cookie-set"){assert(value=="1");set++;if(set==2)normal.clear_cookies();}
        if(kind=="cookies"){assert(phase==1);assert(value.contains("app=yes"));success=true;normal.close();app.close();}
        if(kind=="closed")loop.quit();
    });
    uint deadline=Timeout.add_seconds(45,()=>{normal.close();app.close();loop.quit();return Source.REMOVE;});
    message("CEF test: starting GLib loop");loop.run();Source.remove(deadline);MajorisCef.shutdown();
    stdout.printf("Browser cookies cleared; independent web-app cookies %s\n",success?"preserved":"FAILED");
    return success?0:1;
}
