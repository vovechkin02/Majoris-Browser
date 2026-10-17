namespace MajorisBrowser {
    public class PermissionService : Object {
        private StoreWorker worker;
        private string profile;
        private Gee.ArrayList<Record> policies=new Gee.ArrayList<Record>();
        private Mutex mutex;
        private Cond condition;
        private bool ready;
        private Error? failure;
        public signal void policies_changed(string profile);
        public PermissionService(StoreWorker worker,string profile="browser") throws Error {
            this.worker=worker;this.profile=profile;
            worker.run((store)=>{try{policies=store.site_policies(profile);foreach(var row in policies)row.folder=store.permission_value(profile,row.url,row.title).to_string();}catch(Error e){failure=e;}mutex.lock();ready=true;condition.signal();mutex.unlock();});
            mutex.lock();while(!ready)condition.wait(mutex);mutex.unlock();if(failure!=null)throw failure;
        }
        public string serialized(){var b=new Json.Builder();b.begin_array();foreach(var row in policies){b.begin_object();b.set_member_name("origin");b.add_string_value(row.url);b.set_member_name("kind");b.add_string_value(row.title);b.set_member_name("value");b.add_int_value(int.parse(row.folder));b.end_object();}b.end_array();var g=new Json.Generator();g.set_root(b.get_root());return g.to_data(null);}
        private void update(string origin,string kind,int value){foreach(var row in policies)if(row.url==origin && row.title==kind){row.folder=value.to_string();return;}policies.add(new Record(0,origin,kind,value.to_string()));}
        public void attach(MajorisCef.View view,bool ephemeral=false){
            if(ephemeral)return;ulong handler=policies_changed.connect((changed)=>{if(changed==profile)view.set_permissions(serialized());});
            view.event.connect((kind,value)=>{if(kind=="closed")disconnect(handler);});
        }
        public void reload(){worker.run((store)=>{var rows=store.site_policies(profile);foreach(var row in rows)row.folder=store.permission_value(profile,row.url,row.title).to_string();Idle.add(()=>{policies=rows;policies_changed(profile);return Source.REMOVE;});});}
        public async int decision(string profile,string origin,string[] kinds){
            string[] requested=kinds.copy();
            int result=1;SourceFunc resume=decision.callback;
            worker.run((store)=>{
                try{foreach(string kind in requested){int value=store.permission_value(profile,origin,kind);if(value==2){result=2;break;}if(value==0)result=0;}}catch(Error e){result=0;}
                Idle.add((owned)resume);
            });yield;return result;
        }
        public void remember(string profile,string origin,string[] kinds,int value){
            string[] requested=kinds.copy();
            worker.run((store)=>{string canonical=UrlResolver.origin(origin);foreach(string kind in requested)store.permission(profile,canonical,kind,value);Idle.add(()=>{if(profile==this.profile)foreach(string kind in requested)update(canonical,kind,value);policies_changed(profile);return Source.REMOVE;});});
        }
        public void reset(string profile,string origin){worker.run((store)=>{string canonical=UrlResolver.origin(origin);store.reset_permissions(profile,canonical);Idle.add(()=>{if(profile==this.profile)foreach(var row in policies)if(row.url==canonical)row.folder="0";policies_changed(profile);return Source.REMOVE;});});}
    }
}
