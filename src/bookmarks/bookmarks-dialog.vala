namespace MajorisBrowser {
    public class BookmarksDialog : Adw.Dialog {
        private Application app;
        private Gtk.ListBox list=new Gtk.ListBox();
        private Gtk.SearchEntry search=new Gtk.SearchEntry();
        private uint generation;
        public signal void open_url(string url,bool window);
        public BookmarksDialog(Application app){
            this.app=app;title=_("Bookmarks");content_width=750;content_height=600;
            var layout=new Adw.ToolbarView();var header=new Adw.HeaderBar();var add=new Gtk.Button.from_icon_name("list-add-symbolic");add.clicked.connect(()=>edit(null));header.pack_start(add);
            var folder=new Gtk.Button.with_label(_("Folders"));folder.clicked.connect(manage_folders);header.pack_start(folder);
            var import_button=new Gtk.Button.with_label(_("Import"));import_button.clicked.connect(()=>transfer.begin(true));header.pack_end(import_button);
            var export_button=new Gtk.Button.with_label(_("Export"));export_button.clicked.connect(()=>transfer.begin(false));header.pack_end(export_button);layout.add_top_bar(header);
            var box=new Gtk.Box(Gtk.Orientation.VERTICAL,6);box.append(search);var scroll=new Gtk.ScrolledWindow();scroll.vexpand=true;scroll.child=list;box.append(scroll);layout.content=box;child=layout;
            search.search_changed.connect(refresh);closed.connect(()=>generation++);refresh();
        }
        private void refresh(){uint current=++generation;string query=search.text;app.storage.run((store)=>{var records=store.search(true,query);Idle.add(()=>{
            if(current!=generation)return Source.REMOVE;app.bookmarks_changed();while(list.get_first_child()!=null)list.remove(list.get_first_child());
            foreach(var record in records){var row=new Adw.ActionRow();row.use_markup=false;row.title=record.title;row.subtitle=(record.folder==""?"":record.folder+" · ")+record.url;row.activatable=true;row.activated.connect(()=>open_url(record.url,false));
                button(row,"document-edit-symbolic",()=>edit(record));button(row,"window-new-symbolic",()=>open_url(record.url,true));button(row,"user-trash-symbolic",()=>{app.storage.run((store)=>{store.remove(true,record.id);Idle.add(()=>{refresh();return Source.REMOVE;});});});list.append(row);
            }return Source.REMOVE;
        });});}
        public void edit_bookmark(Record record){edit(record);}
        private delegate void Click();
        private void button(Adw.ActionRow row,string icon,owned Click click){var b=new Gtk.Button.from_icon_name(icon);b.valign=Gtk.Align.CENTER;b.clicked.connect(()=>click());row.add_suffix(b);}
        private void edit(Record? record){
            var dialog=new Adw.AlertDialog(record==null?_("Add Bookmark"):_("Edit Bookmark"),null);var box=new Gtk.Box(Gtk.Orientation.VERTICAL,8);var title=new Gtk.Entry();title.placeholder_text=_("Title");var url=new Gtk.Entry();url.placeholder_text=_("URL");var folder=new Gtk.Entry();folder.placeholder_text=_("Folder");
            if(record!=null){title.text=record.title;url.text=record.url;folder.text=record.folder;}box.append(title);box.append(url);box.append(folder);dialog.extra_child=box;dialog.add_response("cancel",_("Cancel"));dialog.add_response("save",_("Save"));
            dialog.response.connect((id)=>{if(id!="save")return;try{UrlResolver.web_uri(url.text);string target=url.text,name=title.text,group=folder.text;app.storage.run((store)=>{if(record==null)store.bookmark(target,name,group);else store.edit_bookmark(record.id,target,name,group);Idle.add(()=>{refresh();return Source.REMOVE;});});}catch(Error e){EngineDialogs.show_error(this,e.message);}});dialog.present(this);
        }
        private void manage_folders(){
            var dialog=new Adw.AlertDialog(_("Bookmark Folders"),_("Renaming moves the folder’s bookmarks. Deleting a folder keeps its bookmarks at the top level."));var box=new Gtk.Box(Gtk.Orientation.VERTICAL,6);var old=new Gtk.Entry();old.placeholder_text=_("Existing Folder");var name=new Gtk.Entry();name.placeholder_text=_("New Folder Name");box.append(old);box.append(name);dialog.extra_child=box;
            dialog.add_response("cancel",_("Cancel"));dialog.add_response("create",_("Create"));dialog.add_response("rename",_("Rename"));dialog.add_response("delete",_("Delete Folder"));dialog.response.connect((id)=>{string from=old.text,to=name.text;if(id=="cancel")return;app.storage.run((store)=>{if(id=="create")store.create_folder(to);else if(id=="rename")store.rename_folder(from,to);else store.delete_folder(from);Idle.add(()=>{refresh();return Source.REMOVE;});});});dialog.present(this);
        }
        private async void transfer(bool importing){
            var dialog=new Gtk.FileDialog();dialog.initial_name="bookmarks.html";
            try{
                if(importing){var file=yield dialog.open(get_root() as Gtk.Window,null);var info=yield file.query_info_async(FileAttribute.STANDARD_SIZE,FileQueryInfoFlags.NONE,Priority.DEFAULT,null);if(info.get_size()>8*1024*1024)throw new IOError.INVALID_DATA("Bookmark file is too large");uint8[] bytes;yield file.load_contents_async(null,out bytes,null);string text=(string)bytes;app.storage.run((store)=>{foreach(var record in BookmarkFormat.parse(text))store.bookmark(record.url,record.title,record.folder);Idle.add(()=>{refresh();return Source.REMOVE;});});}
                else{var file=yield dialog.save(get_root() as Gtk.Window,null);app.storage.run((store)=>{try{string text=BookmarkFormat.export_html(store.search(true,"",-1));file.replace_contents(text.data,null,false,FileCreateFlags.PRIVATE,null);}catch(Error e){string error=e.message;Idle.add(()=>{EngineDialogs.show_error(this,error);return Source.REMOVE;});}});}
            }catch(Error e){EngineDialogs.show_error(this,e.message);}
        }
    }
}
