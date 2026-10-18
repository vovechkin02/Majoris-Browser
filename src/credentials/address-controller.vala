namespace MajorisBrowser {
    public class AddressController : Object {
        private Application app;
        private BrowserSurface surface;
        private bool busy;
        public AddressController(Application app,BrowserSurface surface){this.app=app;this.surface=surface;surface.changed.connect((kind,value)=>{if(kind=="address-offer" && !busy && !surface.closed)offer(value);});}
        private void offer(string text){
            try{
                var parser=new Json.Parser();parser.load_from_data(text);var event=parser.get_root().get_object();string origin=event.get_string_member("origin");int64 context=event.get_int_member("context");if(UrlResolver.origin(surface.url)!=UrlResolver.origin(origin))return;busy=true;
                app.storage.run((store)=>{
                    var profiles=new Gee.ArrayList<Record>();try{profiles=store.addresses();}catch(Error e){}Idle.add(()=>{
                        if(surface.closed || profiles.size==0){busy=false;return Source.REMOVE;}
                        try{if(UrlResolver.origin(surface.url)!=UrlResolver.origin(origin)){busy=false;return Source.REMOVE;}}catch(Error e){busy=false;return Source.REMOVE;}
                        var names=new Gee.ArrayList<string>();foreach(var profile in profiles)names.add(profile.title);var selection=new Gtk.DropDown.from_strings(names.to_array());var dialog=new Adw.AlertDialog(_("Fill Address Details?"),origin);dialog.extra_child=selection;dialog.add_response("cancel",_("Not Now"));dialog.add_response("fill",_("Fill Selected Address"));dialog.close_response="cancel";
                        dialog.response.connect((id)=>{
                            busy=false;if(id!="fill" || surface.closed)return;
                            try{if(UrlResolver.origin(surface.url)!=UrlResolver.origin(origin))return;var data=new Json.Parser();data.load_from_data(profiles[(int)selection.selected].folder);data.get_root().get_object().set_int_member("__majorisContext",context);var generator=new Json.Generator();generator.set_root(data.get_root());surface.engine.fill_address(origin,generator.to_data(null));}catch(Error e){EngineDialogs.show_error(surface,e.message);}
                        });ulong closing=surface.notify["closed"].connect(()=>{if(surface.closed)dialog.force_close();});dialog.closed.connect(()=>surface.disconnect(closing));dialog.present(surface);return Source.REMOVE;
                    });
                });
            }catch(Error e){busy=false;}
        }
    }
}
