namespace MajorisBrowser {
    public enum ThreatVerdict { NO_KNOWN_THREAT, MALWARE, PHISHING, UNWANTED_SOFTWARE, UNKNOWN, CHECK_FAILED }
    public enum DownloadAssessment { NOT_ASSESSED, PENDING, MALICIOUS, UNAVAILABLE, POLICY_BLOCKED }
    public class ThreatResult : Object {
        public ThreatVerdict verdict;
        public uint cache_seconds;
        public ThreatResult(ThreatVerdict verdict,uint cache_seconds=0){this.verdict=verdict;this.cache_seconds=uint.min(cache_seconds,60);}
        public bool dangerous { get { return verdict==ThreatVerdict.MALWARE || verdict==ThreatVerdict.PHISHING || verdict==ThreatVerdict.UNWANTED_SOFTWARE; } }
    }
}
