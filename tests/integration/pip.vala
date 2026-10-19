using MajorisBrowser;
class PipProbe : Object {
    string root;string target;string mode;string generation="";
    OffscreenBrowserSurface surface;Gtk.Window window;MainLoop loop=new MainLoop();
    int step;int play_next;bool success;bool custom;
    public PipProbe(string[] args){root=args[3];target=args[4];mode=args[5];custom=MajorisCef.has_native_pip();
        surface=new OffscreenBrowserSurface(Path.build_filename(root,"profile"),mode=="private",target,mode=="app"?UrlResolver.origin(target)+"/":"");
        window=new Gtk.Window();window.title="Majoris PiP fixture";window.set_default_size(800,500);window.child=surface;surface.engine.event.connect(event);window.present();
    }
    void marker(string name){try{FileUtils.set_contents(Path.build_filename(root,name),"1");}catch(Error e){error("%s",e.message);}}
    bool flag(string name){return FileUtils.test(Path.build_filename(root,name),FileTest.EXISTS);}
    void click_play(int next){play_next=next;step=24;surface.grab_focus();surface.engine.focus(true);surface.engine.evaluate("new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(()=>resolve(document.getElementById('start').getBoundingClientRect().height===60))))");}
    void event(string kind,string value){
        try{
            if(kind=="loading" && value=="0"){
                if(step==0)click_play(1);
                else if(step==6){Timeout.add(100,()=>{if(!flag("navigation-verified"))return Source.CONTINUE;click_play(7);return Source.REMOVE;});}
                else if(step==13){step=14;surface.engine.command("context-media:"+generation+":pip");}
                else if(step==19)click_play(20);
            }
            if(kind=="operation-error"){
                if(step==2 && !custom){assert(value=="picture-in-picture");marker("unsupported");success=true;surface.close();}
                else if(step==14){assert(value.contains("selection"));click_play(15);}
                else error("PiP step %d failed: %s",step,value);
            }
            if(kind=="operation-complete" && value=="picture-in-picture"){
                if(step==2){step=3;surface.engine.evaluate("document.pictureInPictureElement===primary");}
                else if(step==5){step=6;marker("navigating");surface.navigate(target+"?navigation");}
                else if(step==8){step=9;surface.engine.evaluate("secondary.play().then(()=>true)");}
                else if(step==16){step=17;surface.engine.command("tasks");}
                else if(step==21){step=22;marker("source-closing");success=true;surface.close();}
            }
            if(kind=="context" && step==10){var p=new Json.Parser();p.load_from_data(value);var context=p.get_root().get_object();assert(context.get_int_member("media")==2);generation=context.get_string_member("generation");step=11;surface.engine.command("context-media:"+generation+":pip");}
            if(kind=="operation-complete" && value=="context-media" && step==11){step=12;surface.engine.evaluate("document.pictureInPictureElement===secondary");}
            if(kind=="evaluation"){
                var p=new Json.Parser();p.load_from_data(value);var response=p.get_root().get_object();assert(!response.has_member("exceptionDetails"));bool result=response.get_object_member("result").get_boolean_member("value");
                if(step==24){assert(result);step=play_next;surface.engine.pointer(1,80,30,1,0,0,0);surface.engine.pointer(2,80,30,1,0,0,0);Timeout.add(400,()=>{surface.engine.evaluate("primary.readyState>=2&&!primary.paused");return Source.REMOVE;});}
                else if(step==1){assert(result);step=2;surface.engine.command("picture-in-picture");}
                else if(step==3){assert(result);marker("pip-open");step=4;surface.engine.evaluate("document.pictureInPictureElement===null");}
                else if(step==4){if(result){step=23;surface.engine.evaluate("primary.play().then(()=>true)");}else Timeout.add(150,()=>{surface.engine.evaluate("document.pictureInPictureElement===null");return Source.REMOVE;});}
                else if(step==23){assert(result);step=5;surface.engine.command("picture-in-picture");}else if(step==7){assert(result);step=8;surface.engine.command("picture-in-picture");}
                else if(step==9){assert(result);step=10;surface.engine.pointer(1,450,160,3,0,0,0);surface.engine.pointer(2,450,160,3,0,0,0);}
                else if(step==12){assert(result);step=13;surface.navigate(target+"?stale");}
                else if(step==15){assert(result);step=16;surface.engine.command("picture-in-picture");}
                else if(step==20){assert(result);step=21;surface.engine.command("picture-in-picture");}
            }
            if(kind=="tasks" && step==17){string id="";foreach(string line in value.split("\n")){var f=line.split("\t");if(f.length>=9 && f[8]=="1" && f[4]=="1")id=f[0];}assert(id!="");step=18;surface.engine.command("kill-task:"+id);}
            if(kind=="crashed" && step==18){marker("crashed");Timeout.add(100,()=>{if(!flag("crash-verified"))return Source.CONTINUE;step=19;surface.navigate(target+"?close");return Source.REMOVE;});}
            if(kind=="closed")loop.quit();
        }catch(Error e){error("%s",e.message);}
    }
    public void run(){uint timer=Timeout.add_seconds(45,()=>{stderr.printf("PiP lifecycle timeout at step %d\n",step);surface.close();loop.quit();return Source.REMOVE;});loop.run();Source.remove(timer);window.destroy();assert(success);}
}
int main(string[] args){try{Environment.set_prgname((Environment.get_variable("CHROME_DESKTOP")??"com.majoris.browser.desktop").replace(".desktop",""));Gtk.init();MajorisCef.initialize(args[3],args[1],args[2]);new PipProbe(args).run();MajorisCef.shutdown();stdout.printf("GTK/CEF PiP lifecycle, selected video, stale context and renderer cleanup: PASS\n");}catch(Error e){error("%s",e.message);}return 0;}
