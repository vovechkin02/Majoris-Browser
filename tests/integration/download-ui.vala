using MajorisBrowser;
namespace MajorisBrowser {
    public class Application : Object {
        public StoreWorker storage;public WebApp? webapp;public DownloadService downloads;
        public Application(string root,DownloadSecurityProvider scanner){storage=new StoreWorker(root+"/state.db");downloads=new DownloadService(this,scanner);}
    }
    public class EngineDialogs : Object {public static void show_error(Gtk.Widget parent,string message){error("Unexpected UI error: %s",message);}}
}
class HealthFixture : DownloadSecurityProvider {
    public ScannerState mode=ScannerState.NOT_CONFIGURED;
    public override bool configured {get{return mode!=ScannerState.NOT_CONFIGURED;}}
    public override async void probe(){state=mode;status_detail="Deterministic scanner health fixture";}
    public override async FileAssessment assess(string path,Cancellable cancel) throws Error {
        SourceFunc resume=assess.callback;ulong handler=cancel.cancelled.connect(()=>Idle.add((owned)resume));yield;cancel.disconnect(handler);cancel.set_error_if_cancelled();return new FileAssessment(DownloadAssessment.SCAN_FAILED);
    }
}
Gtk.Button? button(Gtk.Widget widget,string label){var found=widget as Gtk.Button;if(found!=null && found.label==label)return found;for(var child=widget.get_first_child();child!=null;child=child.get_next_sibling()){var result=button(child,label);if(result!=null)return result;}return null;}
async void tick(){SourceFunc resume=tick.callback;Timeout.add(60,()=>{resume();return Source.REMOVE;});yield;}
async void verify(MainLoop loop,string root){
    var scanner=new HealthFixture();var app=new MajorisBrowser.Application(root,scanner);var record=new DownloadRecord();record.status="complete";record.filename="fixture.txt";app.downloads.records.add(record);
    var parent=new Gtk.Window();parent.present();var dialog=new DownloadsDialog(app,null);dialog.present(parent);
    yield tick();assert(button(dialog,"Scan")==null && app.downloads.records.contains(record));
    scanner.mode=ScannerState.AVAILABLE;yield app.downloads.refresh_scanner();yield tick();var scan=button(dialog,"Scan");assert(scan!=null);scan.clicked();yield tick();assert(record.assessment==DownloadAssessment.PENDING && !record.may_open);var cancel=button(dialog,"Cancel Scan");assert(cancel!=null);cancel.clicked();yield tick();assert(record.assessment==DownloadAssessment.SCAN_FAILED && app.downloads.records.contains(record));
    scanner.mode=ScannerState.OUTDATED;yield app.downloads.refresh_scanner();yield tick();assert(button(dialog,"Scan")!=null && app.downloads.scanner_label=="Signatures Outdated");
    scanner.mode=ScannerState.UNAVAILABLE;yield app.downloads.refresh_scanner();yield tick();assert(button(dialog,"Scan")==null && app.downloads.records.contains(record));
    dialog.close();parent.destroy();app.storage.stop();stdout.printf("GTK Downloads: no Scan without health, actual Scan/Cancel transitions, stale warning, unavailable record retained: PASS\n");loop.quit();
}
int main(string[] args){Gtk.init();Adw.init();var loop=new MainLoop();verify.begin(loop,args[1]);loop.run();return 0;}
