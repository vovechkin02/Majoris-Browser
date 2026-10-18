namespace MajorisBrowser {
    // An approved adapter must implement maintained local-list/hash-prefix
    // matching, rate limits, attribution and permitted cache lifetimes. Never
    // treat this interface as a configured remote service.
    public abstract class ThreatProvider : Object {
        public abstract bool configured { get; }
        public abstract async ThreatResult lookup(string url_sha256,Cancellable cancellable) throws Error;
    }
    public class UnconfiguredThreatProvider : ThreatProvider {
        public override bool configured { get { return false; } }
        public override async ThreatResult lookup(string hash,Cancellable cancellable) throws Error {return new ThreatResult(ThreatVerdict.UNKNOWN);}
    }
}
