int main(string[] args){
    try{MajorisCef.initialize(args[3],args[1],args[2]);var loop=new MainLoop();var normal=new MajorisCef.View(Path.build_filename(args[3],"browser"),false,args[4]);var app=new MajorisCef.View(Path.build_filename(args[3],"installed-app"),false,args[4],args[4]);bool normal_started=false,app_started=false;int completed=0;
        foreach(var view in new MajorisCef.View[]{normal,app}){
            view.event.connect((kind,value)=>{
                if(kind=="title" && value=="media-started"){if(view==normal)normal_started=true;else app_started=true;}
                if(kind=="title" && value=="media-complete")view.evaluate("JSON.stringify(window.mediaReport)");
                if(kind=="evaluation")try{var parser=new Json.Parser();parser.load_from_data(value);string report=parser.get_root().get_object().get_object_member("result").get_string_member("value");stdout.printf("%s playback: %s\n",view==normal?"Browser":"Installed-app context",report);parser.load_from_data(report);var result=parser.get_root().get_object();assert(!result.has_member("error"));foreach(string format in new string[]{"vp8","vp9","opus","webm"})assert(result.get_boolean_member(format));bool h264=result.get_string_member("h264")!="",aac=result.get_string_member("aac")!="";if(Environment.get_variable("MAJORIS_EXPECT_PROPRIETARY_CODECS")=="1")assert(h264&&aac);if(h264)assert(result.get_boolean_member("h264Playback"));if(aac)assert(result.get_boolean_member("aacPlayback"));if(h264&&aac)assert(result.get_boolean_member("mp4Playback"));completed++;view.close();if(completed==2)loop.quit();}catch(Error e){error("%s",e.message);}
            });
        }
        uint clicks=Timeout.add(150,()=>{if(!normal_started){normal.focus(true);normal.pointer(1,50,30,1,0,0,0);normal.pointer(2,50,30,1,0,0,0);}if(!app_started){app.focus(true);app.pointer(1,50,30,1,0,0,0);app.pointer(2,50,30,1,0,0,0);}return Source.CONTINUE;});uint timer=Timeout.add_seconds(25,()=>{normal.close();app.close();loop.quit();return Source.REMOVE;});loop.run();Source.remove(timer);Source.remove(clicks);MajorisCef.shutdown();assert(completed==2);
    }catch(Error e){error("%s",e.message);}return 0;
}
