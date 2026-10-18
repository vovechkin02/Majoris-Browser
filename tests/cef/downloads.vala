using MajorisBrowser;
// Minimal application owner, using the production service and SQLite worker.
namespace MajorisBrowser { public class Application : Object {
    public StoreWorker storage;public WebApp? webapp;
    public Application(string path){storage=new StoreWorker(path);}
}}
int main(string[] args){
    if(args.length==3 && args[1]=="--verify-store"){
        try{string path=Path.build_filename(args[2],"private-download.bin");assert(FileUtils.test(path,FileTest.IS_REGULAR));var store=new Store(Path.build_filename(args[2],"service.db"));assert(store.download_records().size>0);foreach(string text in store.download_records()){var record=DownloadRecord.parse(text);assert(!record.ephemeral && record.session=="" && record.destination!=path);}stdout.printf("Separate-process restart: private metadata absent and downloaded file retained: PASS\n");return 0;}catch(Error e){error("%s",e.message);}
    }
    try{MajorisCef.initialize(args[3],args[1],args[2]);}catch(Error e){error("%s",e.message);}
    var owner=new MajorisBrowser.Application(Path.build_filename(args[3],"service.db"));var service=new DownloadService(owner);
    var foreign=new DownloadRecord();foreign.profile="other-installed-app";service.records.add(foreign);assert(!service.owns(foreign,""));service.remove(foreign,"");assert(service.records.contains(foreign));service.records.remove(foreign);
    var view=new MajorisCef.View(Path.build_filename(args[3],"browser"),false,"about:blank");service.attach(view);
    var secret=new MajorisCef.View("private-one",true,"about:blank");service.attach(secret,"private-one");
    var sibling=new MajorisCef.View("private-one",true,"about:blank");service.attach(sibling,"private-one");
    var other=new MajorisCef.View("private-two",true,"about:blank");service.attach(other,"private-two");
    var loop=new MainLoop();bool paused=false,resumed=false,complete=false,cancelled=false,private_complete=false;int destination=0,closed=0;var stable=new DownloadRecord();
    string private_path=Path.build_filename(args[3],"private-download.bin");
    secret.request.connect((token,kind,origin,message)=>secret.reply(token,kind=="download",private_path));
    secret.event.connect((kind,text)=>{
        if(kind=="download"){
            service.update(secret,text,true);
            foreach(var record in service.records)if(record.ephemeral){
                assert(!service.owns(record,"") && !service.owns(record,"private-two") && service.owns(record,"private-one"));
                service.command(record,"cancel","");service.remove(record,"");assert(!service.retry(record,view,""));
                if(record.status=="complete"){
                    private_complete=true;assert(FileUtils.test(private_path,FileTest.IS_REGULAR));
                    service.clear_completed("");assert(service.owns(record,"private-one"));
                    assert(!record.serialize().contains("private-one"));secret.close();break;
                }
            }
        }
        if(kind=="closed"){
            service.view_closed(secret);bool retained=false;foreach(var record in service.records)if(record.ephemeral)retained=true;assert(retained);sibling.close();
        }
    });
    sibling.event.connect((kind,text)=>{if(kind=="closed"){
        service.view_closed(sibling);foreach(var record in service.records)assert(!record.ephemeral);
        assert(FileUtils.test(private_path,FileTest.IS_REGULAR));other.close();
    }});
    other.event.connect((kind,text)=>{if(kind=="closed"){service.view_closed(other);view.close();}});
    view.request.connect((token,kind,origin,message)=>{if(kind=="download")view.reply(token,true,Path.build_filename(args[3],"download-"+(destination++).to_string()+".bin"));else view.reply(token,false,"");});
    view.event.connect((kind,text)=>{
        if(kind=="ready")view.command("download:"+args[4]);
        if(kind=="download")try{
            service.update(view,text,false);
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
            else if(status=="cancelled"){cancelled=true;secret.command("download:"+args[4]);}
        }catch(Error e){error("%s",e.message);}
        if(kind=="closed"){service.view_closed(view);closed++;loop.quit();}
    });
    uint timeout=Timeout.add_seconds(30,()=>{secret.close();sibling.close();other.close();view.close();loop.quit();return Source.REMOVE;});loop.run();Source.remove(timeout);service.flush();owner.storage.stop();
    try{var store=new Store(Path.build_filename(args[3],"service.db"));foreach(string text in store.download_records()){var record=DownloadRecord.parse(text);assert(!record.ephemeral && record.destination!=private_path && record.session=="");}var software=new DownloadRecord();software.filename="installer.AppImage";assert(software.risky_to_open());software.filename="document.txt";assert(!software.risky_to_open());}catch(Error e){error("%s",e.message);}
    MajorisCef.shutdown();assert(complete && cancelled && private_complete && closed==1);stdout.printf("Real downloads: pause/resume, cancellation, scoped private visibility/actions/session cleanup, persistence and file retention: PASS\n");return 0;
}
