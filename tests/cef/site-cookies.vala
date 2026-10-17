int main(string[] args){
    try{MajorisCef.initialize(args[3],args[1],args[2]);}catch(Error e){error("%s",e.message);}
    var normal=new MajorisCef.View(Path.build_filename(args[3],"browser"),false,"about:blank");var app=new MajorisCef.View(Path.build_filename(args[3],"app"),false,"about:blank");var loop=new MainLoop();int ready=0,set=0,phase=0;bool success=false;
    SourceFunc begin=()=>{if(++ready==2){normal.set_cookie_details("https://sub.example.test/","shared","yes",".example.test","/elsewhere",true,true);normal.set_cookie_details("https://sub.example.test/","host","yes","","/elsewhere",true,false);normal.set_cookie("https://notexample.test/","unrelated","keep");app.set_cookie_details("https://sub.example.test/","app","yes",".example.test","/elsewhere",true,true);}return Source.REMOVE;};
    SourceFunc written=()=>{if(++set==4)normal.clear_site_cookies("https://sub.example.test/path");return Source.REMOVE;};
    normal.event.connect((kind,value)=>{
        if(kind=="ready")begin();if(kind=="cookie-set"){assert(value=="1");written();}
        if(kind=="operation-error")error("%s",value);
        if(kind=="cookies-cleared"){assert(value=="2");normal.get_cookies("https://sub.example.test/elsewhere");}
        if(kind=="cookies" && phase==0){assert(value=="");phase=1;normal.get_cookies("https://notexample.test/");}
        else if(kind=="cookies" && phase==1){assert(value.contains("unrelated=keep"));phase=2;app.get_cookies("https://sub.example.test/elsewhere");}
    });
    app.event.connect((kind,value)=>{if(kind=="ready")begin();if(kind=="cookie-set"){assert(value=="1");written();}if(kind=="cookies"){assert(phase==2);assert(value.contains("app=yes"));success=true;normal.close();app.close();}if(kind=="closed")loop.quit();});
    uint timer=Timeout.add_seconds(20,()=>{normal.close();app.close();loop.quit();return Source.REMOVE;});loop.run();Source.remove(timer);MajorisCef.shutdown();assert(success);stdout.printf("Scoped Secure/HttpOnly host and domain-cookie clearing: PASS\n");return 0;
}
