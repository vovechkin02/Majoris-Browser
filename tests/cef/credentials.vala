using MajorisBrowser;
MainLoop loop;
bool success=false;
async void exercise(string[] args){
    try{
        string origin=UrlResolver.origin(args[4]);var secrets=new CredentialStore("browser");var other=new CredentialStore("app-fixture");
        yield secrets.save(origin,"fixture-user","fixture-password");yield secrets.save(origin,"second-user","second-password");assert((yield secrets.usernames(origin)).size==2);assert((yield other.usernames(origin)).size==0);assert((yield other.lookup(origin,"fixture-user"))==null);
        assert((yield secrets.lookup(origin,"fixture-user"))=="fixture-password");
        MajorisCef.initialize(args[3],args[1],args[2]);var view=new MajorisCef.View(Path.build_filename(args[3],"browser"),false,args[4]);
        int phase=0;
        view.event.connect((kind,value)=>{
            if(kind=="credential-form" && phase==0){phase=1;view.autofill("https://unrelated.test/","wrong","must-not-fill");view.evaluate("document.querySelector('[type=password]').value");}
            if(kind=="evaluation")try{var p=new Json.Parser();p.load_from_data(value);string result=p.get_root().get_object().get_object_member("result").get_string_member("value");
                if(phase==1){assert(result=="");phase=10;view.autofill(origin,"fixture-user","fixture-password");}
                else if(phase==2){assert(result=="fixture-user|fixture-password|undefined");phase=20;view.focus(true);view.evaluate("new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(()=>resolve('ready-to-submit'))))");}
                else if(phase==20){assert(result=="ready-to-submit");phase=21;view.pointer(1,50,120,1,0,0,0);view.pointer(2,50,120,1,0,0,0);}
            }catch(Error e){error("%s",e.message);}
            if(kind=="credential-filled" && phase==10){phase=2;view.evaluate("document.querySelector('[name=username]').value+'|'+document.querySelector('[type=password]').value+'|'+typeof majorisCredentialSubmit");}
            if(kind=="credential-fill-refused" && phase==10)error("Matching-origin fill failed: %s",value);
            if(kind=="credential-submit")try{var p=new Json.Parser();p.load_from_data(value);var o=p.get_root().get_object();assert(UrlResolver.origin(o.get_string_member("origin"))==origin);assert(o.get_string_member("username")=="fixture-user");assert(o.get_string_member("password")=="fixture-password");phase=3;}catch(Error e){error("%s",e.message);}
            if(kind=="credential-complete" && phase==3){success=true;view.close();}
            if(kind=="closed")loop.quit();
        });
        Timeout.add_seconds(25,()=>{view.close();loop.quit();return Source.REMOVE;});
    }catch(Error e){stderr.printf("Credential integration: %s\n",e.message);loop.quit();}
}
void main(string[] args){loop=new MainLoop();exercise.begin(args);loop.run();MajorisCef.shutdown();assert(success);stdout.printf("Secret Service isolation, HTTPS origin autofill and trusted form submission: PASS\n");}
