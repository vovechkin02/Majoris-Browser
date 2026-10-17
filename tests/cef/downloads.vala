using MajorisBrowser;
int main(string[] args){
    try{MajorisCef.initialize(args[3],args[1],args[2]);}catch(Error e){error("%s",e.message);}
    var view=new MajorisCef.View(Path.build_filename(args[3],"browser"),false,"about:blank");var loop=new MainLoop();bool paused=false,resumed=false,complete=false,cancelled=false;int destination=0;var stable=new DownloadRecord();
    view.request.connect((token,kind,origin,message)=>{if(kind=="download")view.reply(token,true,Path.build_filename(args[3],"download-"+(destination++).to_string()+".bin"));else view.reply(token,false,"");});
    view.event.connect((kind,text)=>{
        if(kind=="ready")view.command("download:"+args[4]);
        if(kind=="download")try{
            var parser=new Json.Parser();parser.load_from_data(text);var data=parser.get_root().get_object();string status=data.get_string_member("status");uint id=(uint)data.get_int_member("id");
            if(!complete){
                if(status=="active" && !paused && data.get_int_member("received")>0){paused=true;view.command("download-pause:"+id.to_string());}
                if(status=="paused" && !resumed){resumed=true;view.command("download-resume:"+id.to_string());}
                if(status=="complete"){
                    assert(paused && resumed);string path=data.get_string_member("path");uint8[] bytes;FileUtils.get_data(path,out bytes);assert(bytes.length==2*1024*1024);assert(data.get_int_member("received")==bytes.length);
                    stable.source=data.get_string_member("source");stable.destination=path;stable.filename=Path.get_basename(path);stable.status=status;stable.received=data.get_int_member("received");stable.total=data.get_int_member("total");stable.completed=new DateTime.now_utc().to_unix();
                    {var store=new Store(Path.build_filename(args[3],"downloads.db"));store.save_download(stable.id,stable.serialize());}
                    {var store=new Store(Path.build_filename(args[3],"downloads.db"));var restored=DownloadRecord.parse(store.download_records()[0]);assert(restored.id==stable.id && restored.destination==path && restored.control==null && restored.status=="complete");}
                    complete=true;view.command("download:"+args[4]);
                }
            }else if(status=="active")view.command("download-cancel:"+id.to_string());
            else if(status=="cancelled"){cancelled=true;view.close();}
        }catch(Error e){error("%s",e.message);}
        if(kind=="closed")loop.quit();
    });
    uint timeout=Timeout.add_seconds(25,()=>{view.close();loop.quit();return Source.REMOVE;});loop.run();Source.remove(timeout);MajorisCef.shutdown();assert(complete && cancelled);stdout.printf("Real download pause/resume, completion, persistence and cancellation: PASS\n");return 0;
}
