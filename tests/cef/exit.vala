using MajorisBrowser;
int main(string[] args){
    try{
        MajorisCef.initialize(args[3],args[1],args[2]);
        var first=new MajorisCef.View(Path.build_filename(args[3],"browser"),false,args[4]);
        var second=new MajorisCef.View(Path.build_filename(args[3],"browser"),false,args[4]);
        var app=new MajorisCef.View(Path.build_filename(args[3],"fixture"),false,"about:blank");
        var exit=new ExitOperation();var loop=new MainLoop();int phase=0,prompts=0,closed=0;bool success=false,loaded=false,cookies=false;
        SourceFunc prepare=()=>{if(phase==0 && loaded && cookies){phase=1;second.focus(true);second.evaluate("document.body.innerHTML='<button style=\"position:fixed;left:0;top:0;width:150px;height:80px\">Edit</button>';document.querySelector('button').onclick=()=>{window.onbeforeunload=e=>{e.preventDefault();e.returnValue=1;};document.title='edited';};'prepared'");}return Source.REMOVE;};
        first.request.connect((token,kind,origin,message)=>first.reply(token,true,""));
        second.request.connect((token,kind,origin,message)=>{assert(kind=="confirm");prompts++;second.reply(token,prompts>1,"");});
        app.event.connect((kind,value)=>{if(kind=="ready")app.set_cookie("https://fixture.test/","app","yes");if(kind=="cookie-set"){assert(value=="1");first.set_cookie("https://fixture.test/","normal","yes");}});
        first.event.connect((kind,value)=>{
            if(kind=="cookie-set"){assert(value=="1");cookies=true;prepare();}
            if(kind=="closed"){closed++;assert(!exit.finish(false));}
        });
        second.event.connect((kind,value)=>{
            if(kind=="loading" && value=="0"){loaded=true;prepare();}
            if(kind=="evaluation" && phase==1){phase=2;}
            if(kind=="title" && value=="edited" && phase==2){phase=3;assert(exit.begin(true));assert(!exit.begin(true));first.request_close();second.request_close();}
            if(kind=="close-cancelled"){assert(phase==3 && prompts==1);exit.cancel();assert(!exit.finish(true));phase=4;second.get_cookies("https://fixture.test/");}
            if(kind=="cookies" && phase==4){assert(value.contains("normal=yes"));assert(!exit.finish(true));phase=5;second.evaluate("document.title");}
            if(kind=="evaluation" && phase==5){assert(value.contains("edited"));assert(!exit.finish(true));assert(exit.begin(true));phase=6;second.request_close();}
            if(kind=="closed"){closed++;assert(closed==2 && prompts==2 && phase==6);assert(exit.approve(true));assert(!exit.finish(false));success=true;app.close();}
        });
        app.event.connect((kind,value)=>{if(kind=="closed")loop.quit();});
        uint click=Timeout.add(150,()=>{if(phase==2){second.pointer(0,40,30,0,0,0,0);second.pointer(1,40,30,1,0,0,0);second.pointer(2,40,30,1,0,0,0);}return Source.CONTINUE;});
        uint timeout=Timeout.add_seconds(20,()=>{first.close();second.close();app.close();loop.quit();return Source.REMOVE;});
        loop.run();Source.remove(click);Source.remove(timeout);MajorisCef.shutdown();assert(success);
        assert(exit.finish(true));MajorisCef.clear_profile(Path.build_filename(args[3],"browser"));assert(!exit.finish(true));
        assert(!FileUtils.test(Path.build_filename(args[3],"browser"),FileTest.EXISTS));assert(FileUtils.test(Path.build_filename(args[3],"fixture"),FileTest.IS_DIR));
        stdout.printf("Multi-view clear-on-exit cancellation retains cookies; later confirmed exit clears only Browser: PASS\n");
    }catch(Error e){error("%s",e.message);}return 0;
}
