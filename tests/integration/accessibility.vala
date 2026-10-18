using MajorisBrowser;
int main(string[] args){
    try{Gtk.init();MajorisCef.initialize(args[3],args[1],args[2]);var surface=new OffscreenBrowserSurface(Path.build_filename(args[3],"browser"),false,args[4]);var window=new Gtk.Window();window.title="Majoris accessibility fixture";window.set_default_size(800,500);window.child=surface;var loop=new MainLoop();
        bool scheduled=false;surface.changed.connect((kind,value)=>{if(kind=="closed")loop.quit();if(kind=="loading" && value=="0" && !scheduled){scheduled=true;Timeout.add_seconds(3,()=>{surface.grab_focus();surface.engine.evaluate("document.body.style.marginLeft='80px';document.querySelector('#name').focus();document.querySelector('#name').value='Updated text';document.querySelector('#name').setSelectionRange(2,7);document.querySelector('#live').textContent='Fixture activated'");return Source.REMOVE;});}});window.close_request.connect(()=>{surface.close();return false;});window.present();uint timer=Timeout.add_seconds(35,()=>{surface.close();loop.quit();return Source.REMOVE;});loop.run();Source.remove(timer);window.destroy();MajorisCef.shutdown();
    }catch(Error e){error("%s",e.message);}return 0;
}
