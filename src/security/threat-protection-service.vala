namespace MajorisBrowser {
    public class ThreatProtectionService : Object {
        private ThreatProvider provider;
        private ThreatCache cache=new ThreatCache();
        private uint timeout_ms;
        public bool configured { get { return provider.configured; } }
        public void clear_context(string context){cache.clear_context(context);}
        public ThreatProtectionService(ThreatProvider? provider=null,uint timeout_ms=3000){this.provider=provider??new UnconfiguredThreatProvider();this.timeout_ms=timeout_ms;}
        public static string lookup_hash(string url) throws Error {
            var uri=UrlResolver.web_uri(url);
            // Strip query/fragment/user data before the adapter boundary. The
            // remaining path is hashed locally; no raw URL goes to a provider.
            string key=UrlResolver.origin(url)+WebAppNavigationPolicy.normalized_path(url);
            return Checksum.compute_for_string(ChecksumType.SHA256,key);
        }
        public async ThreatResult check(string context,string url,Cancellable? navigation=null) throws Error {
            if(!configured)return new ThreatResult(ThreatVerdict.UNKNOWN);
            string hash;try{hash=provider.cache_key(url);}catch(Error e){return new ThreatResult(ThreatVerdict.UNKNOWN);}
            if(navigation!=null && navigation.is_cancelled())return new ThreatResult(ThreatVerdict.CHECK_FAILED);
            string key=context+":"+hash;var saved=cache.get_result(key);if(saved!=null){var copy=new ThreatResult(saved.verdict);copy.provider_name=saved.provider_name;return copy;}
            var cancel=new Cancellable();bool done=false;var result=new ThreatResult(ThreatVerdict.CHECK_FAILED);SourceFunc resume=check.callback;
            uint timer=0;timer=Timeout.add(timeout_ms,()=>{timer=0;if(!done){done=true;cancel.cancel();Idle.add((owned)resume);}return Source.REMOVE;});
            ulong handler=0;if(navigation!=null)handler=navigation.cancelled.connect(()=>{if(!done){done=true;cancel.cancel();Idle.add((owned)resume);}});
            provider.lookup_url.begin(url,cancel,(object,response)=>{ThreatResult answer;try{answer=provider.lookup_url.end(response);}catch(Error e){answer=new ThreatResult(ThreatVerdict.CHECK_FAILED);}if(done)return;result=answer;done=true;Idle.add((owned)resume);});
            yield;if(timer!=0)Source.remove(timer);if(handler!=0)navigation.disconnect(handler);
            if(navigation==null || !navigation.is_cancelled())cache.put(key,result);return result;
        }
    }
}
