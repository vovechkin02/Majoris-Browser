namespace MajorisBrowser {
    // CEF owns the initial gesture; Gdk.Drag.begin starts its GTK4 source drag.
    public class WebDrag : Object {
        private weak BrowserSurface surface;
        private Gdk.Device? device;
        private Gdk.Drag? drag;
        private Gdk.DragAction performed;
        public static void attach(BrowserSurface surface){new WebDrag(surface);}
        private WebDrag(BrowserSurface surface){
            this.surface=surface;
            var events=new Gtk.EventControllerLegacy();events.propagation_phase=Gtk.PropagationPhase.CAPTURE;events.event.connect((event)=>{if(event.get_event_type()==Gdk.EventType.BUTTON_PRESS || event.get_event_type()==Gdk.EventType.MOTION_NOTIFY)device=event.get_device();return false;});surface.add_controller(events);
            surface.changed.connect((kind,value)=>{if(kind=="drag-start")start(value);});
            surface.notify["closed"].connect(()=>{if(surface.closed)finish(false);});
        }
        private void start(string text){
            try{
                var parser=new Json.Parser();parser.load_from_data(text);var data=parser.get_root().get_object();
                var native=surface.get_native();if(surface.closed || drag!=null || native==null || device==null)throw new IOError.NOT_SUPPORTED("No active drag device");
                var providers=new Gee.ArrayList<Gdk.ContentProvider>();
                string plain=data.get_string_member("text"),html=data.get_string_member("html"),link=data.get_string_member("link");
                if(plain!="")providers.add(new Gdk.ContentProvider.for_bytes("text/plain;charset=utf-8",new Bytes(plain.data)));
                if(html!="")providers.add(new Gdk.ContentProvider.for_bytes("text/html",new Bytes(html.data)));
                if(link!="")try{UrlResolver.web_uri(link);providers.add(new Gdk.ContentProvider.for_bytes("text/uri-list",new Bytes((link+"\r\n").data)));if(plain=="")providers.add(new Gdk.ContentProvider.for_bytes("text/plain;charset=utf-8",new Bytes(link.data)));}catch(Error e){}
                if(data.has_member("file")){
                    uint8[] bytes=Base64.decode(data.get_string_member("file"));if(bytes.length>32*1024*1024)throw new IOError.INVALID_DATA("Drag content exceeds the limit");
                    string name=Path.get_basename(data.get_string_member("name"));if(name=="" || name=="." || name=="..")name="download";
                    string directory=DirUtils.make_tmp("majoris-drag-XXXXXX");var file=File.new_for_path(Path.build_filename(directory,name));file.replace_contents(bytes,null,false,FileCreateFlags.PRIVATE,null);
                    providers.insert(0,new Gdk.ContentProvider.for_bytes("text/uri-list",new Bytes((file.get_uri()+"\r\n").data)));
                    // Receivers may copy a URI after consuming the drop.
                    Timeout.add_seconds(300,()=>{try{file.delete();}catch(Error e){}DirUtils.remove(directory);return Source.REMOVE;});
                }
                if(providers.size==0)throw new IOError.NOT_SUPPORTED("No transferable drag formats");
                int allowed=(int)data.get_int_member("operations");Gdk.DragAction actions=0;
                if((allowed&1)!=0)actions|=Gdk.DragAction.COPY;if((allowed&2)!=0)actions|=Gdk.DragAction.LINK;if((allowed&16)!=0)actions|=Gdk.DragAction.MOVE;
                if(actions==0)throw new IOError.NOT_SUPPORTED("No permitted drag operation");
                drag=Gdk.Drag.begin(native.get_surface(),device,new Gdk.ContentProvider.union(providers.to_array()),actions,0,0);
                if(drag==null)throw new IOError.NOT_SUPPORTED("The display could not start the drag");performed=0;
                drag.drop_performed.connect(()=>{if(drag!=null)performed=drag.get_selected_action();});
                drag.cancel.connect(()=>finish(false));drag.dnd_finished.connect(()=>finish(true));
                if(data.has_member("icon")){var icon=Gdk.Texture.from_bytes(new Bytes(Base64.decode(data.get_string_member("icon"))));Gtk.DragIcon.set_from_paintable(drag,icon,(int)data.get_int_member("hotX"),(int)data.get_int_member("hotY"));}
                else{var icon=Gtk.DragIcon.get_for_drag(drag) as Gtk.DragIcon;if(icon!=null)icon.child=new Gtk.Image.from_icon_name("document-send-symbolic");}
            }catch(Error e){if(drag!=null)finish(false);else surface.engine.drag_end(-1,-1,0);}
        }
        private void finish(bool accepted){
            if(drag==null)return;var current=drag;drag=null;
            var selected=current.get_selected_action();if(selected==0)selected=performed;
            int operation=!accepted?0:(selected&Gdk.DragAction.MOVE)!=0?16:(selected&Gdk.DragAction.LINK)!=0?2:(selected&Gdk.DragAction.COPY)!=0?1:0;
            int x=-1,y=-1;double px,py;var native=surface.get_native();
            var at=current.get_device().get_surface_at_position(out px,out py);
            if(native!=null && at==native.get_surface()){
                Graphene.Point point={(float)px,(float)py},local;
                if(((Gtk.Widget)native).compute_point(surface,point,out local)){x=(int)local.x;y=(int)local.y;}
            }
            surface.engine.drag_end(x,y,operation);current.drop_done(accepted && operation!=0);
        }
    }
}
