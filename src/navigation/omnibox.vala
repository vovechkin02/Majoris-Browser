namespace MajorisBrowser {
    public delegate Gee.ArrayList<Record> OpenTabSuggestions();
    public class Omnibox : Object {
        private Gtk.Entry entry;
        private Application app;
        private Gtk.Popover popover=new Gtk.Popover();
        private Gtk.ListBox results=new Gtk.ListBox();
        private uint timer;
        private uint generation;
        private Cancellable? request;
        private OpenTabSuggestions open_tabs;
        private bool updating;
        public signal void accepted(string url);
        public Omnibox(Gtk.Entry entry,Application app,owned OpenTabSuggestions open_tabs){
            this.entry=entry;this.app=app;this.open_tabs=(owned)open_tabs;
            popover.set_parent(entry);popover.autohide=false;popover.has_arrow=false;popover.child=results;results.selection_mode=Gtk.SelectionMode.SINGLE;
            results.row_activated.connect((row)=>accept(row));
            entry.changed.connect(()=>{
                if(updating || !entry.has_focus)return;if(timer!=0)Source.remove(timer);if(request!=null)request.cancel();
                uint token=++generation;timer=Timeout.add(160,()=>{timer=0;query(token,entry.text.strip());return Source.REMOVE;});
            });
            var keys=new Gtk.EventControllerKey();keys.propagation_phase=Gtk.PropagationPhase.CAPTURE;
            keys.key_pressed.connect((key,code,state)=>{
                if(key==Gdk.Key.Escape){popover.popdown();return true;}
                if(!popover.visible)return false;
                if(key==Gdk.Key.Down || key==Gdk.Key.Up){var selected=results.get_selected_row();int index=selected==null?-1:selected.get_index();var next=results.get_row_at_index(index+(key==Gdk.Key.Down?1:-1));if(next!=null)results.select_row(next);return true;}
                if(key==Gdk.Key.Return && results.get_selected_row()!=null){accept(results.get_selected_row());return true;}return false;
            });entry.add_controller(keys);
            entry.activate.connect(()=>popover.popdown());
            var menu=new Menu();menu.append(_("Copy Current URL"),"win.copy-url");menu.append(_("Paste and Go"),"win.paste-go");menu.append(_("Paste and Search"),"win.paste-search");menu.append(_("Clear Address"),"win.clear-address");entry.extra_menu=menu;
        }
        public void set_address(string url){updating=true;entry.text=url;updating=false;}
        public void close(){generation++;if(timer!=0)Source.remove(timer);if(request!=null)request.cancel();popover.popdown();popover.unparent();}
        private void accept(Gtk.ListBoxRow row){var label=row.child as Gtk.Label;if(label!=null){string? url=label.get_data<string>("url");if(url!=null){popover.popdown();accepted(url);}}}
        private void render(Gee.ArrayList<Record> rows,uint token){
            if(token!=generation || !entry.has_focus)return;while(results.get_first_child()!=null)results.remove(results.get_first_child());
            var seen=new Gee.HashSet<string>();int count=0;
            foreach(var record in rows){if(!seen.add(record.url))continue;var label=new Gtk.Label(record.title+"\n"+record.url);label.xalign=0;label.ellipsize=Pango.EllipsizeMode.END;label.margin_start=12;label.margin_end=12;label.margin_top=6;label.margin_bottom=6;label.set_data<string>("url",record.url);results.append(label);if(++count>=12)break;}
            if(count>0){popover.width_request=entry.get_width();popover.popup();}else popover.popdown();
        }
        private void query(uint token,string text){
            if(text==""){popover.popdown();return;}
            var rows=new Gee.ArrayList<Record>();foreach(var item in open_tabs())if((item.url+item.title).down().contains(text.down()))rows.add(item);
            app.storage.run((store)=>{
                try{rows.add_all(store.search(true,text));rows.add_all(store.search(false,text));}catch(Error e){}
                Idle.add(()=>{if(token!=generation || !entry.has_focus)return Source.REMOVE;render(rows,token);if(app.preferences.get_boolean("search-suggestions"))remote.begin(rows,token,text);return Source.REMOVE;});
            });
        }
        private async void remote(Gee.ArrayList<Record> rows,uint token,string text){
            // Opt-in still never transmits likely paths, URLs, credentials or addresses.
            if(text.length<2 || text.length>100 || text.contains(":") || text.contains("/") || text.contains("\\") || text.contains("@"))return;
            string template=app.preferences.get_string("suggest-template");if(template=="" || !template.has_prefix("https://") || !template.contains("%s"))return;
            var cancel=new Cancellable();request=cancel;
            try{
                var session=new Soup.Session();session.timeout=5;var message=new Soup.Message("GET",template.replace("%s",Uri.escape_string(text,null,false)));
                var stream=yield session.send_async(message,Priority.DEFAULT,cancel);
                if(message.status_code!=200)return;var bytes=yield stream.read_bytes_async(65537,Priority.DEFAULT,cancel);if(bytes.get_size()>65536)return;
                string data=(string)bytes.get_data();var parser=new Json.Parser();parser.load_from_data(data,(ssize_t)bytes.get_size());var root=parser.get_root();
                if(root.get_node_type()!=Json.NodeType.ARRAY)return;var array=root.get_array();
                if(array.get_length()>1 && array.get_element(1).get_node_type()==Json.NodeType.ARRAY){foreach(var node in array.get_array_element(1).get_elements())if(node.get_value_type()==typeof(string)){string value=node.get_string();rows.add(new Record(0,app.preferences.get_string("search-template").replace("%s",Uri.escape_string(value,null,false)),value));}}
                if(!cancel.is_cancelled())render(rows,token);
            }catch(Error e){}
        }
    }
}
