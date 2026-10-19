int main(string[] args){
    try{MajorisCef.initialize(args[3],args[1],args[2]);var view=new MajorisCef.View(Path.build_filename(args[3],"browser"),false,args[4]);var loop=new MainLoop();bool success=false;view.set_accessibility(true);
        bool actions_checked=false,custom=false;int action_step=0,button=0;string tree="",document="";
        view.event.connect((kind,value)=>{
            if(kind=="accessibility-tree" && value.contains("Activate fixture") && !success){
                try{
                    FileUtils.set_contents(args[5],value);var parser=new Json.Parser();parser.load_from_data(value);var data=parser.get_root().get_object();tree=data.get_string_member("ax_tree_id");
                    custom=data.has_member("majoris_document");if(custom)document=data.get_string_member("majoris_document");
                    assert(custom==((MajorisCef.capabilities()&2)!=0));
                    foreach(var update in data.get_array_member("updates").get_elements())if(update.get_object().has_member("nodes"))foreach(var node in update.get_object().get_array_member("nodes").get_elements()){var n=node.get_object();if(n.get_string_member("role")=="button" && n.has_member("attributes") && n.get_object_member("attributes").has_member("name") && n.get_object_member("attributes").get_string_member("name")=="Activate fixture")button=(int)n.get_int_member("id");}
                }catch(Error e){error("%s",e.message);}
                success=true;assert(!custom || button>0);view.accessibility_action("malformed-tree","invalid",1,0,"",0,0);
                stderr.printf("AX fixture ready; custom actions: %s\n",custom.to_string());
            }
            if(kind=="accessibility-action")stderr.printf("AX action step %d: %s\n",action_step,value);
            if(kind=="evaluation" && actions_checked)stderr.printf("AX geometry evaluation: %s\n",value);
            if(kind=="accessibility-action" && action_step==0){assert(value=="refused");action_step=1;view.accessibility_action(tree,"stale-document",button,0,"",0,0);}
            else if(kind=="accessibility-action" && action_step==1){assert(value=="refused");action_step=2;if(custom)view.accessibility_action(tree,document,button,0,"",0,0);else{actions_checked=true;view.evaluate("setTimeout(()=>document.body.style.marginLeft='80px',300)");}}
            else if(kind=="accessibility-action" && action_step==2 && custom){assert(value=="dispatched");action_step=3;}
            if(kind=="accessibility-tree" && custom && action_step>=2 && value.contains("Fixture activated")){actions_checked=true;view.evaluate("setTimeout(()=>document.body.style.marginLeft='80px',300)");}
            if(kind=="accessibility-location" && success && actions_checked){try{FileUtils.set_contents(args[5]+".locations",value);}catch(Error e){error("%s",e.message);}view.close();}
            if(kind=="closed")loop.quit();
        });
        uint timer=Timeout.add_seconds(15,()=>{stderr.printf("AX fixture deadline: ready=%s, actions=%s, step=%d\n",success.to_string(),actions_checked.to_string(),action_step);view.close();loop.quit();return Source.REMOVE;});loop.run();Source.remove(timer);MajorisCef.shutdown();assert(success && actions_checked);stdout.printf("Real Chromium AX tree, malformed/stale action rejection and runtime-gated node activation: PASS\n");
    }catch(Error e){error("%s",e.message);}return 0;
}
