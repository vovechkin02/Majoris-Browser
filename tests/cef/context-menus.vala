int main(string[] args){
    try{MajorisCef.initialize(args[3],args[1],args[2]);var view=new MajorisCef.View(Path.build_filename(args[3],"browser"),false,args[4]);var loop=new MainLoop();int step=0;bool success=false;
        SourceFunc context=()=>{int[] x={20,20,20,20,20},y={20,70,125,195,290};view.pointer(1,x[step],y[step],3,0,0,0);view.pointer(2,x[step],y[step],3,0,0,0);return Source.REMOVE;};
        view.event.connect((kind,value)=>{
            try{
                if(kind=="loading" && value=="0" && step==0)view.evaluate("new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(()=>resolve('ready'))))");
                if(kind=="evaluation" && step==0)context();
                if(kind=="context"){
                    var parser=new Json.Parser();parser.load_from_data(value);var data=parser.get_root().get_object();
                    if(step==0){assert(data.get_string_member("link").has_suffix("/link-target") && !data.get_boolean_member("editable"));step=1;Idle.add(()=>{context();return Source.REMOVE;});}
                    else if(step==1){assert(data.get_int_member("media")==1 && data.get_string_member("source").has_prefix("data:image/png"));view.command("copy-context-image");}
                    else if(step==2 || step==3){assert(data.get_boolean_member("editable"));assert((data.get_int_member("editFlags")&64)!=0);view.command("select-all");view.command("cut");view.evaluate(step==2?"document.querySelector('#edit').value":"document.querySelector('#frame').contentDocument.querySelector('#inner').value");}
                    else if(step==4){assert(data.get_string_member("link")=="" && data.get_int_member("media")==0 && !data.get_boolean_member("editable"));step=5;view.command("view-source");}
                }
                if(kind=="image:copy-image" && step==1){uint8[] png=Base64.decode(value);assert(png.length>8 && png[0]==137 && png[1]==80);step=2;context();}
                if(kind=="evaluation" && (step==2 || step==3)){var parser=new Json.Parser();parser.load_from_data(value);assert(parser.get_root().get_object().get_object_member("result").get_string_member("value")=="");step++;context();}
                if(kind=="source-view" && step==5){assert(value.contains("Context fixture") && value.contains("iframe"));success=true;view.close();}
                if(kind=="closed")loop.quit();
            }catch(Error e){error("%s",e.message);}
        });uint timer=Timeout.add_seconds(20,()=>{stderr.printf("Context fixture timed out at step %d\n",step);view.close();loop.quit();return Source.REMOVE;});loop.run();Source.remove(timer);MajorisCef.shutdown();assert(success);stdout.printf("Real page/link/image/edit/frame context descriptors, image bytes, focused-frame cut and page source: PASS\n");
    }catch(Error e){error("%s",e.message);}return 0;
}
