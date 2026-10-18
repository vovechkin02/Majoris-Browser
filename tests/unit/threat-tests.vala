using MajorisBrowser;
class FixtureThreatProvider : ThreatProvider {
    public int calls;
    public ThreatVerdict answer=ThreatVerdict.NO_KNOWN_THREAT;
    public bool hang;
    public bool unavailable;
    public override bool configured { get { return true; } }
    public override async ThreatResult lookup(string hash,Cancellable cancel) throws Error {
        assert(hash.length==64);calls++;if(unavailable)throw new IOError.HOST_UNREACHABLE("fixture outage");if(hang){SourceFunc resume=lookup.callback;ulong handler=cancel.cancelled.connect(()=>Idle.add((owned)resume));yield;cancel.disconnect(handler);throw new IOError.CANCELLED("fixture timeout");}return new ThreatResult(answer,60);
    }
}
async void verify(MainLoop loop){
    try{
    var provider=new FixtureThreatProvider();var service=new ThreatProtectionService(provider,30);
    assert((yield new ThreatProtectionService().check("browser","https://example.test/")).verdict==ThreatVerdict.UNKNOWN);
    foreach(var verdict in new ThreatVerdict[]{ThreatVerdict.MALWARE,ThreatVerdict.PHISHING,ThreatVerdict.UNWANTED_SOFTWARE,ThreatVerdict.NO_KNOWN_THREAT}){provider.answer=verdict;var result=yield service.check("browser","https://example.test/"+((int)verdict).to_string());assert(result.verdict==verdict);assert(result.dangerous==(verdict!=ThreatVerdict.NO_KNOWN_THREAT));}
    int calls=provider.calls;yield service.check("browser","https://example.test/0");assert(provider.calls==calls);yield service.check("installed-app","https://example.test/0");assert(provider.calls==calls+1);service.clear_context("browser");yield service.check("browser","https://example.test/0");assert(provider.calls==calls+2);
    try{assert(ThreatProtectionService.lookup_hash("https://example.test/path?token=secret#private")==ThreatProtectionService.lookup_hash("https://example.test/path"));}catch(Error e){error("%s",e.message);}
    provider.hang=true;assert((yield service.check("browser","https://example.test/timeout")).verdict==ThreatVerdict.CHECK_FAILED);
    var cancelled=new Cancellable();cancelled.cancel();bool refused=false;try{yield service.check("private-session","https://example.test/cancel",cancelled);}catch(IOError.CANCELLED e){refused=true;}assert(refused);
    var active=new Cancellable();Timeout.add(5,()=>{active.cancel();return Source.REMOVE;});refused=false;try{yield service.check("private-session","https://example.test/cancel-active",active);}catch(IOError.CANCELLED e){refused=true;}assert(refused);
    provider.hang=false;provider.unavailable=true;assert((yield service.check("browser","https://example.test/outage")).verdict==ThreatVerdict.CHECK_FAILED);
    assert(DownloadAssessment.NOT_ASSESSED!=DownloadAssessment.MALICIOUS);loop.quit();}catch(Error e){error("%s",e.message);}
}
int main(){var loop=new MainLoop();Idle.add(()=>{verify.begin(loop);return Source.REMOVE;});loop.run();stdout.printf("Provider verdicts, unknown/no-known-threat distinction, timeout, cancellation, profile cache and URL privacy: PASS\n");return 0;}
