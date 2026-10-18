namespace MajorisBrowser {
    public enum ThreatServiceState { NOT_CONFIGURED, UNAVAILABLE, ACTIVE, TEMPORARILY_UNAVAILABLE, SERVICE_ERROR;
        public string label(){switch(this){case ACTIVE:return "Active";case UNAVAILABLE:return "Unavailable";case TEMPORARILY_UNAVAILABLE:return "Temporarily Unavailable";case SERVICE_ERROR:return "Service Error";default:return "Not Configured";}}
    }
    public enum ThreatVerdict { NO_KNOWN_THREAT, MALWARE, PHISHING, UNWANTED_SOFTWARE, UNKNOWN, CHECK_FAILED }
    public enum DownloadAssessment { NOT_ASSESSED, PENDING, MALICIOUS, UNAVAILABLE, POLICY_BLOCKED, NO_KNOWN_THREAT, SCAN_FAILED }
    public class ThreatResult : Object {
        public ThreatVerdict verdict;
        public uint cache_seconds;
        public string provider_name="";
        public ThreatResult(ThreatVerdict verdict,uint cache_seconds=0){this.verdict=verdict;this.cache_seconds=uint.min(cache_seconds,60);}
        public bool dangerous { get { return verdict==ThreatVerdict.MALWARE || verdict==ThreatVerdict.PHISHING || verdict==ThreatVerdict.UNWANTED_SOFTWARE; } }
    }
}
