int main(string[] args){
    try{MajorisCef.initialize(args[3],args[1],args[2]);var view=new MajorisCef.View(Path.build_filename(args[3],"browser"),false,args[4]);var loop=new MainLoop();int phase=0,jobs=0;bool started=false,success=false;
        view.request.connect((token,kind,origin,message)=>{
            if(kind=="print-setup"){if(phase==3)view.close();else if(phase==0)view.reply(token,false,"");else view.reply(token,true,"{\"width\":2550,\"height\":3300,\"landscape\":true}");}
            if(kind=="print-job"){try{uint8[] pdf;FileUtils.get_data(message,out pdf);assert(pdf.length>100 && pdf[0]=='%' && pdf[1]=='P' && pdf[2]=='D' && pdf[3]=='F');var ascii=new StringBuilder();foreach(uint8 b in pdf)ascii.append_c(b>=32 && b<127?(char)b:' ');assert(Regex.match_simple("/MediaBox\\s*\\[0 0 792 612\\]",ascii.str));jobs++;view.reply(token,phase==2,"");}catch(Error e){error("%s",e.message);}}
        });view.event.connect((kind,value)=>{
            if(kind=="loading" && value=="0" && !started){started=true;view.command("print");}
            if(kind=="print-result")assert(value==(phase==1?"cancelled-or-failed":"submitted"));
            if(kind=="print-reset" && phase<3){phase++;Timeout.add(100,()=>{if(phase==2)view.evaluate("setTimeout(()=>window.print(),50);'queued'");else view.command("print");return Source.REMOVE;});}
            if(kind=="closed"){success=jobs==2 && phase==3;loop.quit();}
        });uint timer=Timeout.add_seconds(25,()=>{stderr.printf("Print fixture timed out in phase %d\n",phase);view.close();loop.quit();return Source.REMOVE;});loop.run();Source.remove(timer);MajorisCef.shutdown();assert(success);stdout.printf("CEF print setup cancellation/retry, selected paper/landscape, PDF job rejection/acknowledgement and reset: PASS\n");
    }catch(Error e){error("%s",e.message);}return 0;
}
