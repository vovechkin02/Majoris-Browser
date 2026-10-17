namespace MajorisBrowser {
    public class DownloadRecord : Object {
        public string id=Uuid.string_random();
        public string source="";
        public string destination="";
        public string filename="";
        public int64 received;
        public int64 total;
        public int64 speed;
        public int64 started=new DateTime.now_utc().to_unix();
        public int64 completed;
        public string status="active";
        public string error_detail="";
        public bool ephemeral;
        public uint native_id;
        public MajorisCef.View? control;
        public string serialize(){var b=new Json.Builder();b.begin_object();
            string[] keys={"id","source","destination","filename","status","error"};string[] values={id,source,destination,filename,status,error_detail};for(int i=0;i<keys.length;i++){b.set_member_name(keys[i]);b.add_string_value(values[i]);}
            string[] counts={"received","total","started","completed"};int64[] numbers={received,total,started,completed};for(int i=0;i<counts.length;i++){b.set_member_name(counts[i]);b.add_int_value(numbers[i]);}b.end_object();var g=new Json.Generator();g.set_root(b.get_root());return g.to_data(null);
        }
        public static DownloadRecord parse(string text) throws Error {var p=new Json.Parser();p.load_from_data(text);var o=p.get_root().get_object();var d=new DownloadRecord();d.id=o.get_string_member("id");d.source=o.get_string_member("source");d.destination=o.get_string_member("destination");d.filename=o.get_string_member("filename");d.status=o.get_string_member("status");d.error_detail=o.get_string_member("error");d.received=o.get_int_member("received");d.total=o.get_int_member("total");d.started=o.get_int_member("started");d.completed=o.get_int_member("completed");return d;}
    }
}
