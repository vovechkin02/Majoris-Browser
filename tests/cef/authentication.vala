using MajorisBrowser;
string js_string(string text){var value=new Json.Node(Json.NodeType.VALUE);value.set_string(text);return Json.to_string(value,false);}
int main(string[] args){
    try{
        MajorisCef.initialize(args[3],args[1],args[2]);string origin=UrlResolver.origin(args[4]),scope=origin+"/auth-app/",callback=scope+"callback",state="fixture-state-0123456789";
        string provider=origin.replace("localhost","127.0.0.1")+"/oauth/authorize?response_type=code&client_id=fixture&redirect_uri="+Uri.escape_string(callback,null,false)+"&state="+state;
        var app=new MajorisCef.View.with_permissions(Path.build_filename(args[3],"app-a"),false,args[4],scope,"[{\"origin\":"+js_string(origin)+",\"kind\":\"popups\",\"value\":1}]");var other=new MajorisCef.View(Path.build_filename(args[3],"app-b"),false,args[4],scope);MajorisCef.View? popup=null;var loop=new MainLoop();int stage=0;bool success=false,other_refused=false,intermediate=false,returned=false,opener=false,no_gesture=false,clicked=false;
        other.event.connect((kind,value)=>{if(kind=="loading" && value=="0" && !other_refused)other.load(provider);if(kind=="external"){assert(value==provider);other_refused=true;}});
        app.event.connect((kind,value)=>{
            if(kind=="popup-request")no_gesture=value=="no-gesture";
            if(kind=="loading" && value=="0" && stage==0){stage=1;app.evaluate("document.body.innerHTML='<button style=\"width:200px;height:80px\">Sign In</button>';document.querySelector('button').onclick=()=>{if(window.authScheduled)return;window.authScheduled=true;document.title='auth-clicked';setTimeout(()=>window.open("+js_string(provider)+",'majoris-auth-fixture'),5500);};'ready'");}
            if(kind=="title" && value=="auth-clicked")clicked=true;
            // DOM/rAF completion does not acknowledge Chromium's compositor hit test.
            // Retry actual pointer input until the page acknowledges one trusted click.
            if(kind=="evaluation" && stage==1)Timeout.add(100,()=>{if(clicked || stage!=1)return Source.REMOVE;app.pointer(1,50,30,1,0,0,0);app.pointer(2,50,30,1,0,0,0);return Source.CONTINUE;});
            if(kind=="external" && stage==4){assert(value==provider);stage=5;app.allow_auth_for(provider,1);app.load(provider);Timeout.add(1400,()=>{stage=6;app.load(provider);return Source.REMOVE;});}
            if(kind=="auth-intermediate" && stage==5){assert(value==origin+"/idp/step");app.allow_auth(value);app.load(value);}
            if(kind=="external" && stage==6){assert(value==provider);success=other_refused && intermediate && returned && opener && no_gesture;app.close();other.close();if(popup!=null)popup.close();}
            if(kind=="closed")loop.quit();
        });
        app.popup.connect((child,background,target,new_window)=>{
            assert(stage==1 && target==provider && child.is_auth_popup());popup=child;stage=2;
            child.event.connect((kind,value)=>{
                if(kind=="external" && stage==2){assert(value==provider);child.allow_auth(value);child.load(value);}
                if(kind=="auth-intermediate" && stage==2){assert(value==origin+"/idp/step");intermediate=true;child.allow_auth(value);child.load(value);}
                if(kind=="loading" && value=="0" && intermediate && stage==2){stage=3;child.load(callback+"?code=fixture-code&state="+state);}
                if(kind=="auth-returned"){returned=true;}
                if(kind=="loading" && value=="0" && stage==3)child.evaluate("!!window.opener && window.opener.location.origin===location.origin");
                if(kind=="evaluation" && stage==3){var parser=new Json.Parser();try{parser.load_from_data(value);opener=parser.get_root().get_object().get_object_member("result").get_boolean_member("value");}catch(Error e){error("%s",e.message);}assert(opener && returned);stage=4;app.load(provider);}
            });
        });
        uint timer=Timeout.add_seconds(25,()=>{stderr.printf("Authentication fixture timeout in stage %d\n",stage);app.close();other.close();if(popup!=null)popup.close();loop.quit();return Source.REMOVE;});loop.run();Source.remove(timer);MajorisCef.shutdown();assert(success);stdout.printf("No-gesture auth popup, explicit origin approvals, opener, return revocation, expiry and independent app rejection: PASS\n");
    }catch(Error e){error("%s",e.message);}return 0;
}
