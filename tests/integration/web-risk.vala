using MajorisBrowser;
async void verify(MainLoop loop,string endpoint,string certificate,string untrusted_endpoint){
    try{
        var secret=new ThreatProviderSecret();yield secret.save("fixture-key-not-a-real-credential");
        string? saved=yield secret.load(new Cancellable());assert(saved=="fixture-key-not-a-real-credential");Secret.password_wipe(saved);
        var provider=new WebRiskProvider.fixture(secret,endpoint,certificate);
        assert(provider.state==ThreatServiceState.UNAVAILABLE);
        assert(!WebRiskProvider.consent_matches(true,true,"https://managed.example/check","google-web-risk"));
        assert(!WebRiskProvider.consent_matches(true,true,"https://changed.example/check","https://managed.example/check"));
        assert(WebRiskProvider.consent_matches(true,true,"https://managed.example/check","https://managed.example/check"));
        assert(!WebRiskProvider.consent_matches(false,true,"https://managed.example/check","https://managed.example/check"));
        bool insecure=false;try{WebRiskProvider.validate_managed_endpoint("http://service.invalid/check");}catch(Error e){insecure=true;}assert(insecure);
        var managed_secret=new ThreatProviderSecret("managed-web-risk");yield managed_secret.save("fixture-installation-token");
        var managed=new WebRiskProvider.fixture(managed_secret,endpoint,certificate,true);
        assert((yield new ThreatProtectionService(managed).check("installed-app","https://example.test/managed")).verdict==ThreatVerdict.NO_KNOWN_THREAT);
        assert(managed.state==ThreatServiceState.ACTIVE);yield managed_secret.remove();
        assert(provider.cache_key("https://example.test/a?q=1")!=provider.cache_key("https://example.test/a?q=2"));
        assert(provider.cache_key("https://example.test/a?q=1#secret")==provider.cache_key("https://example.test/a?q=1"));
        bool rejected=false;try{provider.cache_key("https://user:password@example.test/");}catch(Error e){rejected=true;}assert(rejected);
        string[] paths={"clean","malware","phishing","unwanted","malformed","wrong-type","unknown-type","redirect","unauthorised","quota","unavailable","oversize","nul","timeout"};
        ThreatVerdict[] expected={ThreatVerdict.NO_KNOWN_THREAT,ThreatVerdict.MALWARE,ThreatVerdict.PHISHING,ThreatVerdict.UNWANTED_SOFTWARE,ThreatVerdict.CHECK_FAILED,ThreatVerdict.CHECK_FAILED,ThreatVerdict.CHECK_FAILED,ThreatVerdict.CHECK_FAILED,ThreatVerdict.CHECK_FAILED,ThreatVerdict.CHECK_FAILED,ThreatVerdict.CHECK_FAILED,ThreatVerdict.CHECK_FAILED,ThreatVerdict.CHECK_FAILED,ThreatVerdict.CHECK_FAILED};
        for(int i=0;i<paths.length;i++){
            provider=new WebRiskProvider.fixture(secret,endpoint,certificate);var service=new ThreatProtectionService(provider,200);
            assert((yield service.check("browser","https://example.test/"+paths[i]+"?token=fixture#private")).verdict==expected[i]);
            if(paths[i]=="clean")assert(provider.state==ThreatServiceState.ACTIVE);
            if(paths[i]=="unauthorised")assert(provider.state==ThreatServiceState.SERVICE_ERROR);
            if(paths[i]=="quota" || paths[i]=="timeout")assert(provider.state==ThreatServiceState.TEMPORARILY_UNAVAILABLE);
            // A shorter deadline must cancel the queued check before transmission.
            assert((yield new ThreatProtectionService(provider,30).check("browser","https://example.test/limited")).verdict==ThreatVerdict.CHECK_FAILED);
        }
        provider=new WebRiskProvider.fixture(secret,endpoint,certificate);var recovery=new ThreatProtectionService(provider);
        assert((yield recovery.check("browser","https://example.test/clean")).verdict==ThreatVerdict.NO_KNOWN_THREAT);
        provider=new WebRiskProvider.fixture(secret,untrusted_endpoint,certificate);
        assert((yield new ThreatProtectionService(provider).check("browser","https://example.test/untrusted-tls")).verdict==ThreatVerdict.CHECK_FAILED);
        provider=new WebRiskProvider.fixture(secret,endpoint,certificate);var cached=new ThreatProtectionService(provider);
        assert((yield cached.check("app","https://example.test/malware")).provider_name=="Google Web Risk");
        assert((yield cached.check("app","https://example.test/malware")).provider_name=="Google Web Risk");
        int64 before=get_monotonic_time();
        assert((yield recovery.check("browser","https://example.test/clean")).verdict==ThreatVerdict.NO_KNOWN_THREAT);
        assert(get_monotonic_time()-before>500000); // queued, then recovered
        var expiry=new ThreatCache();expiry.put("browser:expiring",new ThreatResult(ThreatVerdict.MALWARE,1));assert(expiry.get_result("browser:expiring")!=null);
        SourceFunc resume=verify.callback;Timeout.add(1100,()=>{resume();return Source.REMOVE;});yield;assert(expiry.get_result("browser:expiring")==null);
        // Same service, independent context keys, concurrent requests and queueing.
        provider=new WebRiskProvider.fixture(secret,endpoint,certificate);var concurrent=new ThreatProtectionService(provider);bool first=false;
        concurrent.check.begin("browser","https://example.test/concurrent-browser",null,(object,response)=>{try{assert(concurrent.check.end(response).verdict==ThreatVerdict.NO_KNOWN_THREAT);first=true;}catch(Error e){error("Concurrent browser check failed");}});
        assert((yield concurrent.check("installed-app","https://example.test/concurrent-app")).verdict==ThreatVerdict.NO_KNOWN_THREAT);assert(first);
        provider=new WebRiskProvider.fixture(secret,endpoint,certificate);var service=new ThreatProtectionService(provider,500);
        var cancel=new Cancellable();Timeout.add(20,()=>{cancel.cancel();return Source.REMOVE;});bool cancelled=false;
        try{yield service.check("private","https://example.test/timeout",cancel);}catch(IOError.CANCELLED e){cancelled=true;}assert(cancelled);
        yield secret.remove();provider=new WebRiskProvider.fixture(secret,endpoint,certificate);
        assert((yield new ThreatProtectionService(provider).check("browser","https://example.test/missing-key")).verdict==ThreatVerdict.CHECK_FAILED);
        assert(provider.state==ThreatServiceState.UNAVAILABLE);
        assert((yield new ThreatProtectionService(new WebRiskProvider(false)).check("browser","https://example.test/disabled")).verdict==ThreatVerdict.UNKNOWN);
        stdout.printf("Web Risk HTTPS, Secret Service, URL privacy/cache keys, verdicts, errors, redirect denial, size limits, rate limits, timeout, cancellation, disabled and missing-key states: PASS\n");
        loop.quit();
    }catch(Error e){error("Provider fixture failed: %s",e.message);}
}
int main(string[] args){var loop=new MainLoop();verify.begin(loop,args[1],args[2],args[3]);loop.run();return 0;}
