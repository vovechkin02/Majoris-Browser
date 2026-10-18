namespace MajorisBrowser {
    // Adapters must enforce their provider's privacy, rate and cache rules.
    // The default implementation never represents a configured remote service.
    public abstract class ThreatProvider : Object {
        public abstract bool configured { get; }
        public virtual ThreatServiceState state {get{return configured?ThreatServiceState.UNAVAILABLE:ThreatServiceState.NOT_CONFIGURED;}}
        public virtual void report_timeout(){}
        public abstract async ThreatResult lookup(string url_sha256,Cancellable cancellable) throws Error;
        // URL-aware providers must explicitly override both methods. Existing
        // hash-only providers retain their privacy contract.
        public virtual string cache_key(string url) throws Error {return ThreatProtectionService.lookup_hash(url);}
        public virtual async ThreatResult lookup_url(string url,Cancellable cancellable) throws Error {return yield lookup(ThreatProtectionService.lookup_hash(url),cancellable);}
    }
    public class UnconfiguredThreatProvider : ThreatProvider {
        public override bool configured { get { return false; } }
        public override async ThreatResult lookup(string hash,Cancellable cancellable) throws Error {return new ThreatResult(ThreatVerdict.UNKNOWN);}
    }
    public class UnavailableThreatProvider : ThreatProvider {
        public override bool configured {get{return true;}}
        public override ThreatServiceState state {get{return ThreatServiceState.SERVICE_ERROR;}}
        public override async ThreatResult lookup(string hash,Cancellable cancel) throws Error {return new ThreatResult(ThreatVerdict.CHECK_FAILED);}
    }
}
