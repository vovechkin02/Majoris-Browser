namespace MajorisBrowser {
    // Adapters must enforce their provider's privacy, rate and cache rules.
    // The default implementation never represents a configured remote service.
    public abstract class ThreatProvider : Object {
        public abstract bool configured { get; }
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
}
