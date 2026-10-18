namespace MajorisBrowser {
    public class NavigationSecurity : Object {
        public static void attach(Application app,BrowserSurface surface,string context){
            surface.engine.set_threat_checks(app.threats.configured);
            var pending=new Gee.ArrayList<Cancellable>();
            surface.changed.connect((kind,value)=>{if(kind=="threat-navigation")foreach(var cancel in pending)cancel.cancel();});
            surface.notify["closed"].connect(()=>{if(surface.closed){foreach(var cancel in pending)cancel.cancel();pending.clear();app.threats.clear_context(context);}});
            surface.engine.request.connect((token,kind,url,message)=>{
                if(kind!="threat-check")return;
                var cancel=new Cancellable();pending.add(cancel);
                app.threats.check.begin(context,url,cancel,(object,response)=>{
                    ThreatResult result;try{result=app.threats.check.end(response);}catch(Error e){pending.remove(cancel);if(!surface.closed)surface.engine.reply(token,false,"");return;}pending.remove(cancel);
                    if(surface.closed)return;
                    if(cancel.is_cancelled()){surface.engine.reply(token,false,"");return;}
                    surface.engine.reply(token,!cancel.is_cancelled() && result.verdict==ThreatVerdict.NO_KNOWN_THREAT,"");
                    if(result.dangerous)SecurityWarning.present(surface,url,result);
                    else if(result.verdict!=ThreatVerdict.NO_KNOWN_THREAT)EngineDialogs.show_error(surface,_("Destination check unavailable. This navigation was cancelled; no safety verdict is available."));
                });
            });
        }
    }
}
