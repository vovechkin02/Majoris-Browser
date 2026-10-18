namespace MajorisBrowser {
    public class WebDrop : Object {
        private weak BrowserSurface surface;
        private weak Gtk.DropTarget target;
        private bool entered;
        private int operation;
        private double x;
        private double y;
        public static void attach(BrowserSurface surface){new WebDrop(surface);}
        private WebDrop(BrowserSurface surface){
            this.surface=surface;var controller=new Gtk.DropTarget(typeof(Gdk.FileList),Gdk.DragAction.COPY);target=controller;target.set_gtypes({typeof(Gdk.FileList),typeof(string)});target.preload=true;
            target.accept.connect(()=>!surface.closed);
            target.enter.connect((px,py)=>{x=px;y=py;begin();return Gdk.DragAction.COPY;});
            target.motion.connect((px,py)=>{x=px;y=py;begin();if(entered)surface.engine.drag_target(1,"","[]",(int)x,(int)y);return Gdk.DragAction.COPY;});
            target.notify["value"].connect(begin);target.leave.connect(leave);
            target.on_drop.connect((value,px,py)=>{x=px;y=py;begin();if(surface.closed || !entered || operation==0){leave();return false;}surface.engine.drag_target(2,"","[]",(int)x,(int)y);entered=false;operation=0;return true;});
            surface.add_controller(target);surface.changed.connect((kind,value)=>{if(kind=="drag-target-cursor" && entered)operation=int.parse(value);if(kind=="navigation-started")leave();});surface.notify["closed"].connect(()=>{if(surface.closed)leave();});
        }
        private void begin(){
            if(entered || surface.closed || target.get_current_drop()==null)return;var value=target.get_value();if(value==null)return;
            string text="";var files=new Json.Builder();files.begin_array();int count=0;
            if(value.type()==typeof(Gdk.FileList)){
                var list=(Gdk.FileList)value.get_boxed();if(list==null)return;foreach(var file in list.get_files()){if(++count>100)break;string? path=file.get_path();if(path!=null)files.add_string_value(path);else try{UrlResolver.web_uri(file.get_uri());text+=(text==""?"":"\n")+file.get_uri();}catch(Error e){}}
            }else{string? plain=value.get_string();if(plain==null || plain.length>8*1024*1024)return;text=plain;}
            files.end_array();var generator=new Json.Generator();generator.set_root(files.get_root());operation=0;entered=true;surface.engine.drag_target(0,text,generator.to_data(null),(int)x,(int)y);
        }
        private void leave(){if(entered){surface.engine.drag_target(3,"","[]",(int)x,(int)y);entered=false;}operation=0;}
    }
}
