namespace MajorisBrowser {
    public class TaskManager : Adw.ApplicationWindow {
        private uint timer;
        public TaskManager (Application app,MajorisCef.View engine) {
            Object(application:app,title:_("Browser Task Manager"),default_width:700,default_height:450);
            var layout=new Adw.ToolbarView();layout.add_top_bar(new Adw.HeaderBar());
            var list=new Gtk.ListBox();list.selection_mode=Gtk.SelectionMode.NONE;
            var sorting=new Gtk.DropDown.from_strings({_("Task Order"),_("CPU Usage"),_("Memory Usage"),_("Name")});layout.add_top_bar(sorting);list.set_sort_func((left,right)=>{
                if(sorting.selected==0)return int.parse(left.get_data<string>("order"))-int.parse(right.get_data<string>("order"));
                if(sorting.selected==3)return strcmp(left.get_data<string>("title"),right.get_data<string>("title"));
                string key=sorting.selected==1?"cpu":"memory";double a=double.parse(left.get_data<string>(key)),b=double.parse(right.get_data<string>(key));return a>b?-1:a<b?1:0;
            });sorting.notify["selected"].connect(()=>list.invalidate_sort());
            var unavailable=new Gtk.Label(_("Task IDs are Chromium task IDs. PID, network metrics and a process hierarchy are unavailable from this CEF task API. CPU is process-wide and can exceed 100%."));unavailable.wrap=true;layout.add_bottom_bar(unavailable);
            var scroll=new Gtk.ScrolledWindow();scroll.child=list;layout.content=scroll;content=layout;
            ulong handler=engine.event.connect((kind,value)=>{
                if(kind!="tasks")return;
                while(list.get_first_child()!=null)list.remove(list.get_first_child());
                int order=0;foreach(var line in value.split("\n")){
                    var f=line.split("\t");if(f.length!=9)continue;
                    var row=new Adw.ActionRow();row.use_markup=false;row.title=f[5].compress();
                    row.set_data<string>("order",(order++).to_string());row.set_data<string>("title",row.title);row.set_data<string>("cpu",f[2]);row.set_data<string>("memory",f[3]);
                    string[] types={"Unknown","Browser","GPU","Zygote","Utility","Renderer","Extension","Guest","Legacy Plugin","Plugin","Sandbox","Worker","Shared Worker","Service Worker"};
                    if(f[8]=="1")row.title+=_(" (Current Page)");
                    int type=int.parse(f[1]);string name=type>=0 && type<types.length?types[type]:"Other";
                    row.subtitle="%s · CPU %.1f%% · %s".printf(name,double.parse(f[2]),int64.parse(f[3])<=0?_("Memory unavailable"):GLib.format_size(uint64.parse(f[3])));
                    row.subtitle+=" · "+_("Task %s").printf(f[0])+" · "+(int64.parse(f[6])<=0?_("GPU memory unavailable"):_("GPU %s").printf(GLib.format_size(uint64.parse(f[6]))))+(f[7]=="1"?_(" (aggregate)"):"");
                    if(f[4]=="1"){
                        string task_id=f[0];var end=new Gtk.Button.with_label(_("End Process"));end.valign=Gtk.Align.CENTER;end.add_css_class("destructive-action");row.add_suffix(end);
                        end.clicked.connect(()=>engine.command("kill-task:"+task_id));
                    }list.append(row);
                }
            });
            engine.command("tasks-start");engine.command("tasks");timer=Timeout.add_seconds(2,()=>{engine.command("tasks");return Source.CONTINUE;});
            close_request.connect(()=>{Source.remove(timer);engine.disconnect(handler);engine.command("tasks-stop");return false;});
        }
    }
}
