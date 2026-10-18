using MajorisBrowser;
MainLoop modern_loop;
bool modern_success=false;
async void finish_modern(CredentialStore secrets,string origin,MajorisCef.View view){
    try{yield secrets.save(origin,"fixture-user","updated-password");assert((yield secrets.lookup(origin,"fixture-user"))=="updated-password");assert((yield secrets.usernames(origin)).size==2);modern_success=true;view.close();}catch(Error e){error("%s",e.message);}
}
async void run_modern(string[] args){
    try{
        string origin=UrlResolver.origin(args[4]);var secrets=new CredentialStore("browser");yield secrets.save(origin,"fixture-user","fixture-password");yield secrets.save(origin,"second-user","second-password");
        MajorisCef.initialize(args[3],args[1],args[2]);var view=new MajorisCef.View(Path.build_filename(args[3],"browser"),false,args[4]);string[] modes={"async","formless","change","frames","fail"};int mode=0,step=0,submissions=0,completions=0;bool current=false;
        SourceFunc next=()=>{mode++;step=0;current=false;view.load(origin+(mode<modes.length?"/modern-login.html?mode="+modes[mode]:"/address.html"));return Source.REMOVE;};
        view.event.connect((kind,text)=>{
            if(kind=="credential-progress")stderr.printf("Modern fixture mode %d: %s\n",mode,text);
            if(kind=="url")current=mode<modes.length?text.has_suffix("?mode="+modes[mode]):text.has_suffix("/address.html");
            if(kind=="credential-form" && current && mode<modes.length && step==0){step=1;view.autofill(origin,"fixture-user","fixture-password");}
            if(kind=="credential-fill-refused" && step==1)error("Modern matching-origin fill was refused: %s",text);
            if(kind=="credential-filled" && step==1){
                step=2;string document=mode==3?"document.querySelector('#same').contentDocument":"document";
                string change=mode==2?"d.querySelector('#new').value='updated-password';d.querySelector('#confirm').value='updated-password';":"";
                view.evaluate("(async()=>{const d="+document+";const correct=d.querySelector('#username').value==='fixture-user'&&d.querySelector('#password').value==='fixture-password'&&typeof d.defaultView.majorisCredentialSubmit==='undefined';"+change+"return correct"+(mode==3?"&&await window.verifyCross()":"")+"?'checked':'incorrect';})()");
            }
            if(kind=="evaluation")try{var parser=new Json.Parser();parser.load_from_data(text);string result=parser.get_root().get_object().get_object_member("result").get_string_member("value");
                if(step==2){assert(result=="checked");step=3;view.focus(true);view.evaluate("new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(()=>resolve('ready'))))");}
                else if(step==3){assert(result=="ready");step=4;}
                else if(step==6){assert(result=="retained");assert(submissions==5 && completions==4);next();}
                else if(step==8){assert(result=="address-ok");finish_modern.begin(secrets,origin,view);}
            }catch(Error e){error("%s",e.message);}
            if(kind=="credential-submit")try{
                assert(step==4);var parser=new Json.Parser();parser.load_from_data(text);var data=parser.get_root().get_object();assert(UrlResolver.origin(data.get_string_member("origin"))==origin);assert(data.get_string_member("username")=="fixture-user");assert(data.get_string_member("password")== (mode==2?"updated-password":"fixture-password"));submissions++;step=5;
            }catch(Error e){error("%s",e.message);}
            if(kind=="credential-complete"){assert(step==5 && mode<4);completions++;next();}
            if(kind=="credential-cancelled" && mode==4 && step==5){step=6;view.evaluate("document.querySelector('#password').value==='fixture-password'?'retained':'lost'");}
            if(kind=="form-observer-ready" && current && mode==5 && step==0){step=7;view.fill_address(origin,"{\"name\":\"Fixture Person\",\"street-address\":\"10 Test St\",\"address-level2\":\"Test City\",\"address-level1\":\"NSW\",\"postal-code\":\"2000\",\"country\":\"AU\",\"tel\":\"123456\",\"email\":\"fixture@example.test\"}");}
            if(kind=="address-filled" && step==7){assert(int.parse(text)==8);step=8;view.evaluate("document.querySelector('#name').value==='Fixture Person'&&document.querySelector('#street').value==='10 Test St'&&document.querySelector('[name=city]').value==='Test City'&&document.querySelector('[name=zip]').value==='2000'&&document.querySelector('select').value==='AU'&&document.querySelector('[name=phone]').value==='123456'&&document.querySelector('#must-stay-empty').value===''?'address-ok':'address-bad'");}
            if(kind=="address-fill-refused" && step==7)error("Semantic address fill was refused");
            if(kind=="closed")modern_loop.quit();
        });
        Timeout.add(150,()=>{if(step==4){int y=mode==3?220:120;view.pointer(0,50,y,0,0,0,0);view.pointer(1,50,y,1,0,0,0);view.pointer(2,50,y,1,0,0,0);}return modern_success?Source.REMOVE:Source.CONTINUE;});
        Timeout.add_seconds(55,()=>{if(!modern_success){stderr.printf("Modern form timeout: mode %d step %d\n",mode,step);view.close();modern_loop.quit();}return Source.REMOVE;});
    }catch(Error e){error("%s",e.message);}
}
int main(string[] args){modern_loop=new MainLoop();run_modern.begin(args);modern_loop.run();MajorisCef.shutdown();assert(modern_success);stdout.printf("Dynamic async/formless/change/same-origin-frame logins, cross-origin exclusion, failed-login refusal, secure address semantics and Secret Service update: PASS\n");return 0;}
