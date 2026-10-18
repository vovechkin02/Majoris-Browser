namespace MajorisBrowser {
    public class ThreatCache : Object {
        private Gee.HashMap<string,ThreatResult> results=new Gee.HashMap<string,ThreatResult>();
        private Gee.HashMap<string,int64?> deadlines=new Gee.HashMap<string,int64?>();
        public ThreatResult? get_result(string key){if(!deadlines.has_key(key) || deadlines[key]<=get_monotonic_time()){results.unset(key);deadlines.unset(key);return null;}return results[key];}
        public void clear_context(string context){foreach(string key in results.keys.to_array())if(key.has_prefix(context+":")){results.unset(key);deadlines.unset(key);}}
        public void put(string key,ThreatResult result){if(result.cache_seconds==0 || result.verdict==ThreatVerdict.UNKNOWN || result.verdict==ThreatVerdict.CHECK_FAILED)return;if(results.size>=256){results.clear();deadlines.clear();}var copy=new ThreatResult(result.verdict,result.cache_seconds);copy.provider_name=result.provider_name;results[key]=copy;deadlines[key]=get_monotonic_time()+result.cache_seconds*1000000;}
    }
}
