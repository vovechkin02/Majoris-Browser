namespace MajorisBrowser {
    // Separate from website credentials and from every browsing profile.
    public class ThreatProviderSecret : Object {
        private Secret.Schema schema=new Secret.Schema("com.majoris.browser.ThreatProvider",Secret.SchemaFlags.NONE,"provider",Secret.SchemaAttributeType.STRING,null);
        public async void save(string key,Cancellable? cancel=null) throws Error {
            if(key.strip()=="" || key.length>512 || key.contains("\n") || key.contains("\r"))throw new IOError.INVALID_ARGUMENT("Invalid provider key");
            if(!yield Secret.password_store(schema,Secret.COLLECTION_DEFAULT,"Majoris Browser · Google Web Risk",key,cancel,"provider","google-web-risk",null))throw new IOError.FAILED("Provider key could not be stored");
        }
        public virtual async string? load(Cancellable cancel) throws Error {return yield Secret.password_lookup(schema,cancel,"provider","google-web-risk",null);}
        public async void remove() throws Error {yield Secret.password_clear(schema,null,"provider","google-web-risk",null);}
    }

    public class WebRiskProvider : ThreatProvider {
        private bool enabled;
        private ThreatProviderSecret secret;
        private Soup.Session session=new Soup.Session();
        private string endpoint="https://webrisk.googleapis.com/v1/uris:search";
        private int64 next_request;
        private int64 backoff_until;
        public override bool configured {get{return enabled;}}
        public WebRiskProvider(bool consent,ThreatProviderSecret? secret=null){enabled=consent;this.secret=secret??new ThreatProviderSecret();session.timeout=3;session.user_agent="Majoris-Browser-WebRisk/1";}
        // Test injection is constrained to loopback; production has no endpoint setting.
        internal WebRiskProvider.fixture(ThreatProviderSecret secret,string endpoint,string certificate) throws Error {
            this(true,secret);var uri=Uri.parse(endpoint,UriFlags.NONE);
            if(uri.get_scheme()!="https" || uri.get_host()!="localhost" || uri.get_userinfo()!=null)throw new IOError.INVALID_ARGUMENT("Fixture requires localhost HTTPS");
            this.endpoint=endpoint;
            session.tls_database=TlsFileDatabase.new(certificate);
        }
        public static string destination(string url) throws Error {
            UrlResolver.web_uri(url);
            if(url.length>8192)throw new IOError.INVALID_ARGUMENT("Destination too long");
            return url.split("#",2)[0];
        }
        public override string cache_key(string url) throws Error {return Checksum.compute_for_string(ChecksumType.SHA256,destination(url));}
        public override async ThreatResult lookup(string hash,Cancellable cancel) throws Error {return new ThreatResult(ThreatVerdict.UNKNOWN);}
        private async void wait_slot(uint delay,Cancellable cancel) throws Error {
            cancel.set_error_if_cancelled();bool waiting=true;SourceFunc resume=wait_slot.callback;
            uint timer=0;timer=Timeout.add(delay,()=>{timer=0;if(waiting){waiting=false;Idle.add((owned)resume);}return Source.REMOVE;});
            ulong handler=cancel.cancelled.connect(()=>{if(waiting){waiting=false;Idle.add((owned)resume);}});
            yield;if(timer!=0)Source.remove(timer);cancel.disconnect(handler);cancel.set_error_if_cancelled();
        }
        public override async ThreatResult lookup_url(string url,Cancellable cancel) throws Error {
            if(!enabled)return new ThreatResult(ThreatVerdict.UNKNOWN);
            string target=destination(url);
            int64 now=get_monotonic_time(),slot=int64.max(now,next_request);
            if(now<backoff_until)return new ThreatResult(ThreatVerdict.CHECK_FAILED);
            // Space ordinary redirects without failing them merely for being
            // fast. Bound queueing below the service deadline; backoff fails closed.
            if(slot-now>1500000)return new ThreatResult(ThreatVerdict.CHECK_FAILED);
            next_request=slot+1000000;
            if(slot>now)yield wait_slot((uint)((slot-now+999)/1000),cancel);
            if(get_monotonic_time()<backoff_until)return new ThreatResult(ThreatVerdict.CHECK_FAILED);
            string? key=yield secret.load(cancel);
            if(key==null)return new ThreatResult(ThreatVerdict.CHECK_FAILED);
            if(key=="" || key.length>512 || key.contains("\n") || key.contains("\r")){Secret.password_wipe(key);return new ThreatResult(ThreatVerdict.CHECK_FAILED);}
            var message=new Soup.Message("GET",endpoint+"?threatTypes=MALWARE&threatTypes=SOCIAL_ENGINEERING&threatTypes=UNWANTED_SOFTWARE&uri="+Uri.escape_string(target,null,false));
            message.set_flags(Soup.MessageFlags.NO_REDIRECT);
            message.request_headers.append("X-Goog-Api-Key",key);Secret.password_wipe(key);key=null;
            try{
                var stream=yield session.send_async(message,Priority.DEFAULT,cancel);
                if(message.status_code!=200){
                    if(message.status_code==429 || message.status_code==503){
                        int64 seconds=60;string? retry=message.response_headers.get_one("Retry-After");int64 parsed;
                        if(retry!=null){if(int64.try_parse(retry,out parsed))seconds=int64.max(seconds,parsed);else{var date=Soup.date_time_new_from_http_string(retry);if(date!=null)seconds=int64.max(seconds,date.to_unix()-new DateTime.now_utc().to_unix());}}
                        backoff_until=get_monotonic_time()+int64.min(seconds,600)*1000000;
                        next_request=int64.max(next_request,backoff_until);
                    }
                    yield stream.close_async(Priority.DEFAULT,cancel);return new ThreatResult(ThreatVerdict.CHECK_FAILED);
                }
                var body=new ByteArray();
                while(true){var chunk=yield stream.read_bytes_async(4096,Priority.DEFAULT,cancel);if(chunk.get_size()==0)break;if(body.len+chunk.get_size()>65536)throw new IOError.INVALID_DATA("Provider response too large");foreach(uint8 value in chunk.get_data())if(value==0)throw new IOError.INVALID_DATA("Invalid response encoding");body.append(chunk.get_data());}
                yield stream.close_async(Priority.DEFAULT,cancel);body.append({0});
                return parse_response((string)body.data);
            }finally{message.request_headers.remove("X-Goog-Api-Key");}
        }
        internal static ThreatResult parse_response(string text) throws Error {
            var parser=new Json.Parser();parser.load_from_data(text);var root=parser.get_root();
            if(root==null || root.get_node_type()!=Json.NodeType.OBJECT)throw new IOError.INVALID_DATA("Invalid provider response");
            var obj=root.get_object();
            if(!obj.has_member("threat")){
                if(obj.get_size()!=0)throw new IOError.INVALID_DATA("Unexpected provider response");
                return new ThreatResult(ThreatVerdict.NO_KNOWN_THREAT); // no negative cache lifetime specified
            }
            var node=obj.get_member("threat");if(node.get_node_type()!=Json.NodeType.OBJECT)throw new IOError.INVALID_DATA("Invalid threat");
            var threat=node.get_object();if(!threat.has_member("threatTypes"))throw new IOError.INVALID_DATA("Missing threat types");var types=threat.get_member("threatTypes");
            if(types==null || types.get_node_type()!=Json.NodeType.ARRAY || types.get_array().get_length()==0)throw new IOError.INVALID_DATA("Missing threat types");
            var verdict=ThreatVerdict.UNWANTED_SOFTWARE;
            foreach(var type in types.get_array().get_elements()){
                if(type.get_value_type()!=typeof(string))throw new IOError.INVALID_DATA("Invalid threat type");
                switch(type.get_string()){
                    case "MALWARE":verdict=ThreatVerdict.MALWARE;break;
                    case "SOCIAL_ENGINEERING":if(verdict!=ThreatVerdict.MALWARE)verdict=ThreatVerdict.PHISHING;break;
                    case "UNWANTED_SOFTWARE":break;
                    default:throw new IOError.INVALID_DATA("Unknown threat type");
                }
            }
            uint ttl=0;
            if(threat.has_member("expireTime")){
                var expiry=threat.get_member("expireTime");if(expiry.get_value_type()!=typeof(string))throw new IOError.INVALID_DATA("Invalid expiry");
                var time=new DateTime.from_iso8601(expiry.get_string(),null);if(time==null)throw new IOError.INVALID_DATA("Invalid expiry");
                int64 remaining=time.to_unix()-new DateTime.now_utc().to_unix();if(remaining>0)ttl=(uint)int64.min(remaining,60);
            }
            var result=new ThreatResult(verdict,ttl);result.provider_name="Google Web Risk";return result;
        }
    }
}
