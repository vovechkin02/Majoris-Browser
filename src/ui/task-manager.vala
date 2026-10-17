namespace MajorisBrowser {
    public class TaskManager : Adw.ApplicationWindow {
        private uint timer;
        public TaskManager (Application app,MajorisCef.View engine) {
            Object(application:app,title:_("Browser Task Manager"),default_width:700,default_height:450);
            var layout=new Adw.ToolbarView();layout.add_top_bar(new Adw.HeaderBar());
            var list=new Gtk.ListBox();list.selection_mode=Gtk.SelectionMode.NONE;
            var scroll=new Gtk.ScrolledWindow();scroll.child=list;layout.content=scroll;content=layout;
            ulong handler=engine.event.connect((kind,value)=>{
                if(kind!="tasks")return;
                while(list.get_first_child()!=null)list.remove(list.get_first_child());
                foreach(var line in value.split("\n")){
                    var f=line.split("\t");if(f.length!=6)continue;
                    var row=new Adw.ActionRow();row.use_markup=false;row.title=f[5].compress();
                    string[] types={"Unknown","Browser","GPU","Zygote","Utility","Renderer","Extension","Guest","Plugin","Sandbox","Worker","Shared Worker","Service Worker"};
                    int type=int.parse(f[1]);string name=type>=0 && type<types.length?types[type]:"Other";
                    row.subtitle="%s · CPU %.1f%% · %s".printf(name,double.parse(f[2]),int64.parse(f[3])<0?_("Memory unavailable"):GLib.format_size(uint64.parse(f[3])));
                    if(f[4]=="1"){
                        string task_id=f[0];var end=new Gtk.Button.with_label(_("End Process"));end.valign=Gtk.Align.CENTER;end.add_css_class("destructive-action");row.add_suffix(end);
                        end.clicked.connect(()=>engine.command("kill-task:"+task_id));
                    }list.append(row);
                }
            });
            engine.command("tasks");timer=Timeout.add_seconds(2,()=>{engine.command("tasks");return Source.CONTINUE;});
            close_request.connect(()=>{Source.remove(timer);engine.disconnect(handler);return false;});
        }
    }
}
