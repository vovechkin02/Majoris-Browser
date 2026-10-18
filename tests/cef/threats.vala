using MajorisBrowser;
class MockReputation : ThreatProvider {
    public string bad_hash;
    public override bool configured { get { return true; } }
    public override async ThreatResult lookup(string hash,Cancellable cancel) throws Error {return new ThreatResult(hash==bad_hash?ThreatVerdict.PHISHING:ThreatVerdict.NO_KNOWN_THREAT);}
}
int main(string[] args){
    try{MajorisCef.initialize(args[3],args[1],args[2]);var view=new MajorisCef.View.with_security(Path.build_filename(args[3],"browser"),false,args[4]+"/good","","[]",true);var mock=new MockReputation();mock.bad_hash=ThreatProtectionService.lookup_hash(args[4]+"/bad");var service=new ThreatProtectionService(mock);var loop=new MainLoop();bool success=false;int phase=0;
        view.request.connect((token,kind,url,message)=>{assert(kind=="threat-check");service.check.begin("browser",url,null,(object,response)=>{try{var result=service.check.end(response);view.reply(token,!result.dangerous,"");if(result.dangerous){assert(url.has_suffix("/bad"));success=true;Timeout.add(100,()=>{view.close();return Source.REMOVE;});}}catch(Error e){error("%s",e.message);}});});
        view.event.connect((kind,value)=>{if(kind=="ready" && phase==0)phase=1;if(kind=="loading" && value=="0" && phase==1){phase=2;view.load(args[4]+"/redirect");}if(kind=="title" && value=="BAD")error("Redirect bypassed reputation check");if(kind=="closed")loop.quit();});
        uint timer=Timeout.add_seconds(15,()=>{view.close();loop.quit();return Source.REMOVE;});loop.run();Source.remove(timer);MajorisCef.shutdown();assert(success);stdout.printf("Deferred real navigation and redirect reputation block before destination fetch: PASS\n");
    }catch(Error e){error("%s",e.message);}return 0;
}
