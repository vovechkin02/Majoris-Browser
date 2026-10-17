int main(string[] args){
    try{MajorisCef.initialize(args[3],args[1],args[2]);}catch(Error e){error("%s",e.message);}
    var view=new MajorisCef.View(Path.build_filename(args[3],"app"),false,args[4]);var loop=new MainLoop();bool loaded=false,success=false;string outcome="timeout";
    view.request.connect((token,kind,origin,message)=>{view.reply(token,kind=="permission:notifications","");});
    view.event.connect((kind,value)=>{
        if(kind=="loading" && value=="0" && !loaded){loaded=true;view.focus(true);}
        // Retry only until the DOM handler acknowledges a real pointer click.
        // A renderer rAF can precede availability of compositor hit-test data.
        if(kind=="evaluation")try{var p=new Json.Parser();p.load_from_data(value);string result=p.get_root().get_object().get_object_member("result").get_string_member("value");if(result=="pending"){view.pointer(0,50,30,0,0,0,0);view.pointer(1,50,30,1,0,0,0);view.pointer(2,50,30,1,0,0,0);}else if(result=="clicked"){outcome=result;success=true;view.close();}else if(result!="requested" && result!="shown"){outcome=result;view.close();}}catch(Error e){error("%s",e.message);}
        if(kind=="closed")loop.quit();
    });
    uint poll=Timeout.add(200,()=>{if(loaded)view.evaluate("document.getElementById('status').textContent");return Source.CONTINUE;});uint timer=0;timer=Timeout.add_seconds(12,()=>{timer=0;view.close();loop.quit();return Source.REMOVE;});loop.run();Source.remove(poll);if(timer!=0)Source.remove(timer);MajorisCef.shutdown();stdout.printf("Native Notification API outcome: %s\n",outcome);return success?0:2;
}
