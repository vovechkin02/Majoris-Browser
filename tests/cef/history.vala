class HistoryProbe : Object {
    string helper;string resources;string root;string origin;
    MajorisCef.View view;
    MainLoop loop=new MainLoop();
    int phase;int epoch;string url="";string saved="";bool back;bool forward;bool restored;bool success;
    bool custom;
    bool crash_seed;bool recover;
    public HistoryProbe(string[] args){helper=args[1];resources=args[2];root=args[3];origin=args[4];custom=(MajorisCef.capabilities()&8)!=0;crash_seed=args.length>5 && args[5]=="crash-seed";recover=args.length>5 && args[5]=="recover";}
    void checkpoint(){
        phase=4;
        if(crash_seed){try{FileUtils.set_contents(Path.build_filename(root,"crash-state"),custom?saved:"invalid");FileUtils.set_contents(Path.build_filename(root,"crash-ready"),"1");}catch(Error e){error("%s",e.message);}}
        else view.close();
    }
    void create(string profile,bool private_mode,string target,string history){
        int generation=++epoch;url="";back=false;forward=false;restored=false;
        view=new MajorisCef.View.with_session(profile,private_mode,target,"","[]",false,history);
        view.event.connect((kind,value)=>{if(generation==epoch)event(kind,value);});
    }
    void event(string kind,string value){
        try{
            if(kind=="url")url=value;
            if(kind=="back")back=value=="1";
            if(kind=="forward")forward=value=="1";
            if(kind=="history-restored"){stderr.printf("History restore phase=%d accepted=%s\n",phase,value);assert(phase!=11);assert(value==(phase==5?"1":"0"));restored=value=="1";}
            if(kind=="history" && phase==3 && custom && value!=""){
                var parser=new Json.Parser();parser.load_from_data(value);var state=parser.get_root().get_object();
                if(state.get_string_member("selected_url")==origin+"/b"){
                    assert(state.get_array_member("entries").get_length()==3 && state.get_int_member("selected")==1);
                    saved=value;checkpoint();
                }
            }
            if(kind=="history" && phase==11)assert_not_reached();
            if(kind=="loading" && value=="0"){
                if(phase==0 && url==origin+"/a"){phase=1;view.load(origin+"/b");}
                else if(phase==1 && url==origin+"/b"){phase=2;view.load(origin+"/c");}
                else if(phase==2 && url==origin+"/c"){phase=3;view.command("back");}
                else if(phase==3 && !custom && url==origin+"/b")checkpoint();
                else if(phase==5 && url==origin+"/b"){
                    phase=6;Timeout.add(200,()=>{assert(back==custom && forward==custom && restored==custom);view.evaluate("fetch('/counts').then(r=>r.text())");return Source.REMOVE;});
                }
                else if(phase==7 && url==origin+"/a"){phase=8;view.command("forward");}
                else if(phase==8 && url==origin+"/b"){phase=9;view.command("forward");}
                else if(phase==9 && url==origin+"/c"){phase=10;view.close();}
                else if(phase==11 && url==origin+"/a")Timeout.add(250,()=>{phase=12;view.close();return Source.REMOVE;});
                else if(phase==13 && url==origin+"/b")Timeout.add(200,()=>{assert(!back && !forward && !restored);phase=14;view.close();return Source.REMOVE;});
                else if((phase==15 || phase==17) && url==origin+"/b")Timeout.add(200,()=>{assert(!back && !forward && !restored);phase++;view.close();return Source.REMOVE;});
            }
            if(kind=="evaluation" && phase==6){
                var parser=new Json.Parser();parser.load_from_data(value);string response=parser.get_root().get_object().get_object_member("result").get_string_member("value");parser.load_from_data(response);var counts=parser.get_root().get_object();
                assert(counts.get_int_member("/a")==1 && counts.get_int_member("/c")==1); // No history URL replay.
                if(custom){phase=7;view.command("back");}else{phase=10;view.close();}
            }
            if(kind=="closed"){
                if(phase==4){phase=5;create(Path.build_filename(root,"browser"),false,origin+"/b",custom?saved:"invalid");}
                else if(phase==10){phase=11;create(Path.build_filename(root,"private"),true,origin+"/a",saved);}
                else if(phase==12){phase=13;create(Path.build_filename(root,"other-profile"),false,origin+"/b",custom?saved:"invalid");}
                else if(phase==14 && custom){
                    var parser=new Json.Parser();parser.load_from_data(saved);parser.get_root().get_object().set_string_member("chromium","incompatible-version");
                    var generator=new Json.Generator();generator.set_root(parser.get_root());phase=15;create(Path.build_filename(root,"browser"),false,origin+"/b",generator.to_data(null));
                }
                else if(phase==16){
                    var parser=new Json.Parser();parser.load_from_data(saved);parser.get_root().get_object().get_array_member("entries").get_element(0).set_string("invalid-pickle");
                    var generator=new Json.Generator();generator.set_root(parser.get_root());phase=17;create(Path.build_filename(root,"browser"),false,origin+"/b",generator.to_data(null));
                }
                else if(phase==14 || phase==18){success=true;loop.quit();}
            }
        }catch(Error e){error("%s",e.message);}
    }
    public void run(){
        if(recover){try{FileUtils.get_contents(Path.build_filename(root,"crash-state"),out saved);}catch(Error e){error("%s",e.message);}phase=5;create(Path.build_filename(root,"browser"),false,origin+"/b",custom?saved:"invalid");}
        else create(Path.build_filename(root,"browser"),false,origin+"/a","invalid");
        uint timer=Timeout.add_seconds(30,()=>{stderr.printf("History fixture timed out at phase %d\n",phase);view.close();loop.quit();return Source.REMOVE;});
        loop.run();Source.remove(timer);assert(success);
    }
}
int main(string[] args){try{MajorisCef.initialize(args[3],args[1],args[2]);new HistoryProbe(args).run();MajorisCef.shutdown();stdout.printf("History selection/back/forward, no URL replay, private exclusion and cross-profile fallback: PASS\n");}catch(Error e){error("%s",e.message);}return 0;}
