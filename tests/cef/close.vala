int main(string[] args){
    try{
        MajorisCef.initialize(args[3],args[1],args[2]);
        var view=new MajorisCef.View(Path.build_filename(args[3],"browser"),false,args[4]);
        var loop=new MainLoop();int phase=0,prompts=0;bool success=false;
        view.request.connect((token,kind,origin,message)=>{
            assert(kind=="confirm");prompts++;view.reply(token,prompts==2,"");
        });
        view.event.connect((kind,text)=>{
            if(kind=="loading" && text=="0" && phase==0){phase=1;view.focus(true);view.evaluate("new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(()=>{document.body.innerHTML='<button style=\"position:absolute;left:0;top:0;width:150px;height:80px\">Edit</button>';document.querySelector('button').onclick=()=>{window.onbeforeunload=e=>{e.preventDefault();e.returnValue='';};document.title='edited';};resolve('ready');})))");}
            if(kind=="evaluation" && phase==1){phase=2;view.pointer(1,40,30,1,0,0,0);view.pointer(2,40,30,1,0,0,0);}
            if(kind=="title" && text=="edited"){phase=3;view.request_close();}
            if(kind=="close-cancelled"){assert(prompts==1);phase=4;view.evaluate("document.title");}
            if(kind=="evaluation" && phase==4){assert(text.contains("edited"));phase=5;view.request_close();}
            if(kind=="closed"){assert(phase==5 && prompts==2);success=true;loop.quit();}
        });
        uint timer=Timeout.add_seconds(15,()=>{view.close();loop.quit();return Source.REMOVE;});
        loop.run();Source.remove(timer);MajorisCef.shutdown();assert(success);
        stdout.printf("Real beforeunload cancellation retains page; accepted close completes: PASS\n");
    }catch(Error e){error("%s",e.message);}return 0;
}
