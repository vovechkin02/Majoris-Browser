namespace MajorisBrowser {
    public class DownloadService : Object {
        public Gee.ArrayList<DownloadRecord> records=new Gee.ArrayList<DownloadRecord>();
        private Application app;
        private Gee.HashSet<DownloadRecord> dirty=new Gee.HashSet<DownloadRecord>();
        private uint save_timer;
        public signal void changed();
        public DownloadService(Application app){this.app=app;app.storage.run((store)=>{
            var saved=store.download_records();Idle.add(()=>{foreach(string item in saved)try{var record=DownloadRecord.parse(item);if(record.profile!=(app.webapp==null?"browser":app.webapp.id))continue;if(record.status=="active" || record.status=="paused"){record.status="failed";record.error_detail=_("Browser closed before this download finished.");persist(record);}records.add(record);}catch(Error e){}changed();return Source.REMOVE;});
        });}
        public void update(MajorisCef.View view,string text,bool ephemeral){
            try{
                var p=new Json.Parser();p.load_from_data(text);var o=p.get_root().get_object();uint id=(uint)o.get_int_member("id");DownloadRecord? record=null;
                foreach(var candidate in records)if(candidate.control==view && candidate.native_id==id){record=candidate;break;}
                if(record==null){record=new DownloadRecord();record.profile=app.webapp==null?"browser":app.webapp.id;record.control=view;record.native_id=id;record.ephemeral=ephemeral;records.insert(0,record);}
                record.source=o.get_string_member("source");record.destination=o.get_string_member("path");record.filename=Path.get_basename(record.destination);record.status=o.get_string_member("status");record.received=o.get_int_member("received");record.total=o.get_int_member("total");record.speed=o.get_int_member("speed");record.error_detail=o.get_string_member("error");
                if(record.status=="complete" || record.status=="cancelled" || record.status=="failed")record.completed=new DateTime.now_utc().to_unix();
                persist(record);changed();
            }catch(Error e){warning("Downloads: %s",e.message);}
        }
        public void remove(DownloadRecord record){if(record.status=="active" || record.status=="paused")return;records.remove(record);if(!record.ephemeral)app.storage.run((store)=>store.remove_download(record.id));changed();}
        public void clear_completed(){var items=new Gee.ArrayList<DownloadRecord>();items.add_all(records);foreach(var record in items)if(record.status=="complete")remove(record);}
        public void clear_history(int64 since){var items=new Gee.ArrayList<DownloadRecord>();items.add_all(records);foreach(var record in items)if(record.profile=="browser" && !record.ephemeral && record.started>=since && record.status!="active" && record.status!="paused"){dirty.remove(record);records.remove(record);}changed();}
        public void command(DownloadRecord record,string action){if(record.control!=null && (record.status=="active" || record.status=="paused"))record.control.command("download-"+action+":"+record.native_id.to_string());}
        private void persist(DownloadRecord record){
            if(record.ephemeral)return;
            if(record.status=="active" || record.status=="paused"){dirty.add(record);if(save_timer==0)save_timer=Timeout.add_seconds(1,()=>{save_timer=0;flush();return Source.REMOVE;});}
            else{dirty.remove(record);string id=record.id,text=record.serialize();app.storage.run((store)=>store.save_download(id,text));}
        }
        public void flush(){if(save_timer!=0){Source.remove(save_timer);save_timer=0;}foreach(var record in dirty){string id=record.id,text=record.serialize();app.storage.run((store)=>store.save_download(id,text));}dirty.clear();}
        public bool active_for(MajorisCef.View view){foreach(var record in records)if(record.control==view && (record.status=="active" || record.status=="paused"))return true;return false;}
        public void view_closed(MajorisCef.View view){var private_records=new Gee.ArrayList<DownloadRecord>();foreach(var record in records)if(record.control==view){if(record.status=="active" || record.status=="paused"){record.status="cancelled";record.completed=new DateTime.now_utc().to_unix();record.error_detail=_("The page hosting this download was closed.");persist(record);}record.control=null;if(record.ephemeral)private_records.add(record);}foreach(var record in private_records)records.remove(record);changed();}
    }
}
