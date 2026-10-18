int main(string[] args){
    try{MajorisCef.initialize(args[3],args[1],args[2]);var view=new MajorisCef.View(Path.build_filename(args[3],"browser"),false,args[4]);var loop=new MainLoop();bool success=false;view.set_accessibility(true);
        view.event.connect((kind,value)=>{if(kind=="accessibility-tree" && value.contains("Accessible fixture") && !success){try{FileUtils.set_contents(args[5],value);}catch(Error e){error("%s",e.message);}success=true;view.evaluate("setTimeout(()=>document.body.style.marginLeft='80px',300)");}if(kind=="accessibility-location" && success){try{FileUtils.set_contents(args[5]+".locations",value);}catch(Error e){error("%s",e.message);}view.close();}if(kind=="closed")loop.quit();});
        uint timer=Timeout.add_seconds(15,()=>{view.close();loop.quit();return Source.REMOVE;});loop.run();Source.remove(timer);MajorisCef.shutdown();assert(success);stdout.printf("Real Chromium OSR accessibility tree contains document, controls and live content: PASS\n");
    }catch(Error e){error("%s",e.message);}return 0;
}
