using MajorisBrowser;
async void verify(MainLoop loop,string endpoint,string certificate,string untrusted_endpoint){
    try{
        var secret=new ThreatProviderSecret();yield secret.save("fixture-key-not-a-real-credential");
        string? saved=yield secret.load(new Cancellable());assert(saved=="fixture-key-not-a-real-credential");Secret.password_wipe(saved);
        var provider=new WebRiskProvider.fixture(secret,endpoint,certificate);
        assert(provider.cache_key("https://example.test/a?q=1")!=provider.cache_key("https://example.test/a?q=2"));
        assert(provider.cache_key("https://example.test/a?q=1#secret")==provider.cache_key("https://example.test/a?q=1"));
        bool rejected=false;try{provider.cache_key("https://user:password@example.test/");}catch(Error e){rejected=true;}assert(rejected);
        string[] paths={"clean","malware","phishing","unwanted","malformed","wrong-type","unknown-type","redirect","unauthorised","quota","unavailable","oversize","nul","timeout"};
        ThreatVerdict[] expected={ThreatVerdict.NO_KNOWN_THREAT,ThreatVerdict.MALWARE,ThreatVerdict.PHISHING,ThreatVerdict.UNWANTED_SOFTWARE,ThreatVerdict.CHECK_FAILED,ThreatVerdict.CHECK_FAILED,ThreatVerdict.CHECK_FAILED,ThreatVerdict.CHECK_FAILED,ThreatVerdict.CHECK_FAILED,ThreatVerdict.CHECK_FAILED,ThreatVerdict.CHECK_FAILED,ThreatVerdict.CHECK_FAILED,ThreatVerdict.CHECK_FAILED,ThreatVerdict.CHECK_FAILED};
        for(int i=0;i<paths.length;i++){
            provider=new WebRiskProvider.fixture(secret,endpoint,certificate);var service=new ThreatProtectionService(provider,200);
            assert((yield service.check("browser","https://example.test/"+paths[i]+"?token=fixture#private")).verdict==expected[i]);
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
        provider=new WebRiskProvider.fixture(secret,endpoint,certificate);var service=new ThreatProtectionService(provider,500);
        var cancel=new Cancellable();Timeout.add(20,()=>{cancel.cancel();return Source.REMOVE;});bool cancelled=false;
        try{yield service.check("private","https://example.test/timeout",cancel);}catch(IOError.CANCELLED e){cancelled=true;}assert(cancelled);
        yield secret.remove();provider=new WebRiskProvider.fixture(secret,endpoint,certificate);
        assert((yield new ThreatProtectionService(provider).check("browser","https://example.test/missing-key")).verdict==ThreatVerdict.CHECK_FAILED);
        assert((yield new ThreatProtectionService(new WebRiskProvider(false)).check("browser","https://example.test/disabled")).verdict==ThreatVerdict.UNKNOWN);
        stdout.printf("Web Risk HTTPS, Secret Service, URL privacy/cache keys, verdicts, errors, redirect denial, size limits, rate limits, timeout, cancellation, disabled and missing-key states: PASS\n");
        loop.quit();
    }catch(Error e){error("Provider fixture failed: %s",e.message);}
}
int main(string[] args){var loop=new MainLoop();verify.begin(loop,args[1],args[2],args[3]);loop.run();return 0;}
