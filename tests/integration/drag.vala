using MajorisBrowser;
int main(string[] args){
    try{
        Gtk.init();MajorisCef.initialize(args[3],args[1],args[2]);
        var source=new OffscreenBrowserSurface(Path.build_filename(args[3],"browser"),false,args[4]);source.set_size_request(400,300);
        var window=new Gtk.Window();window.title="Majoris real drag fixture";window.decorated=false;window.set_default_size(600,300);
        var box=new Gtk.Box(Gtk.Orientation.HORIZONTAL,0);box.append(source);var target=new Gtk.Box(Gtk.Orientation.VERTICAL,0);target.set_size_request(200,300);var label=new Gtk.Label("GTK drop target");label.set_size_request(200,150);target.append(label);var upload=new Gtk.Button.with_label("Drag upload file");upload.set_size_request(200,150);target.append(upload);box.append(target);window.child=box;
        var loop=new MainLoop();int started=0,ended=0;bool link=false,image=false,incoming=false,success=false;var clipboard_entry=new Gtk.Entry();
        string phase=Path.build_filename(args[3],"phase"),file=Path.build_filename(args[3],"upload.txt");FileUtils.set_contents(file,"majoris upload fixture");
        var destination=new Gtk.DropTarget(typeof(Gdk.FileList),Gdk.DragAction.COPY|Gdk.DragAction.LINK);destination.set_gtypes({typeof(Gdk.FileList),typeof(string)});
        destination.on_drop.connect((value,x,y)=>{
            try{
                if(value.type()==typeof(Gdk.FileList)){var files=(Gdk.FileList)value.get_boxed();foreach(var entry in files.get_files()){
                    if(entry.get_uri().has_suffix("/drag-link"))link=true;
                    else if(entry.get_path()!=null){uint8[] data;FileUtils.get_data(entry.get_path(),out data);assert(data.length>8 && data[0]==137 && data[1]==80 && data[2]==78 && data[3]==71);image=true;}
                }}else{string? text=value.get_string();assert(text!=null && text.contains("/drag-link"));link=true;}
            }catch(Error e){error("%s",e.message);}return true;
        });label.add_controller(destination);
        var native_source=new Gtk.DragSource();native_source.actions=Gdk.DragAction.COPY;native_source.prepare.connect(()=>{var files=new Gdk.FileList.from_array({File.new_for_path(file)});Value value=Value(typeof(Gdk.FileList));value.set_boxed(files);return new Gdk.ContentProvider.for_value(value);});upload.add_controller(native_source);
        source.engine.event.connect((kind,value)=>{
            try{
                if(kind=="loading" && value=="0")source.engine.evaluate("new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(()=>resolve('ready'))))");
                if(kind=="evaluation"){assert(source.has_frame);FileUtils.set_contents(phase,"ready");}
                if(kind=="drag-start")started++;
                if(kind=="title" && value=="inbound-ok"){incoming=true;FileUtils.set_contents(phase,"incoming");}
                if(kind=="title" && value=="clipboard-ok")FileUtils.set_contents(phase,"clipboard");
                if(kind=="title" && value=="typed-ok")FileUtils.set_contents(phase,"typed");
                if(kind=="title" && value=="edited-ok"){success=true;FileUtils.set_contents(phase,"done");source.close();}
                if(kind=="drag-ended"){
                    ended++;assert(ended==started);
                    if(ended==1){assert(!link && !image);FileUtils.set_contents(phase,"cancelled");}
                    else if(ended==2){assert(link && !image);FileUtils.set_contents(phase,"link");}
                    else if(ended==3){assert(link && image && incoming);target.remove(label);target.remove(upload);target.append(clipboard_entry);source.get_clipboard().set_text("日本語😀 clipboard");FileUtils.set_contents(phase,"drag-done");}
                }
                if(kind=="closed")loop.quit();
            }catch(Error e){error("%s",e.message);}
        });
        clipboard_entry.notify["text"].connect(()=>{if(clipboard_entry.text=="日本語😀 clipboard")try{FileUtils.set_contents(phase,"native-paste");}catch(Error e){error("%s",e.message);}});
        window.present();uint timer=Timeout.add_seconds(40,()=>{source.close();loop.quit();return Source.REMOVE;});loop.run();Source.remove(timer);window.destroy();MajorisCef.shutdown();assert(success);
        stdout.printf("Actual GTK/X11 pointer drags: CEF link/image to GTK, cancellation, GTK local file to CEF: PASS\n");
    }catch(Error e){error("%s",e.message);}return 0;
}
