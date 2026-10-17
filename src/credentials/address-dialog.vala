namespace MajorisBrowser {
    public class AddressDialog : Adw.Dialog {
        private Application app;
        private BrowserSurface? surface;
        private Gtk.ListBox list=new Gtk.ListBox();
        public AddressDialog(Application app,BrowserSurface? surface=null){
            this.app=app;this.surface=surface;title=_("Address Autofill");content_width=600;content_height=550;var layout=new Adw.ToolbarView();var header=new Adw.HeaderBar();var add=new Gtk.Button.from_icon_name("list-add-symbolic");add.clicked.connect(()=>edit(null));header.pack_start(add);layout.add_top_bar(header);var scroll=new Gtk.ScrolledWindow();scroll.child=list;layout.content=scroll;child=layout;refresh();
        }
        private void refresh(){app.storage.run((store)=>{var records=store.addresses();Idle.add(()=>{while(list.get_first_child()!=null)list.remove(list.get_first_child());foreach(var record in records){var row=new Adw.ActionRow();row.use_markup=false;row.title=record.title;
            var edit_button=new Gtk.Button.from_icon_name("document-edit-symbolic");edit_button.valign=Gtk.Align.CENTER;edit_button.clicked.connect(()=>edit(record));row.add_suffix(edit_button);
            var remove=new Gtk.Button.from_icon_name("user-trash-symbolic");remove.valign=Gtk.Align.CENTER;remove.clicked.connect(()=>{app.storage.run((store)=>{store.delete_address(record.url);Idle.add(()=>{refresh();return Source.REMOVE;});});});row.add_suffix(remove);
            if(surface!=null){var fill=new Gtk.Button.with_label(_("Fill"));fill.valign=Gtk.Align.CENTER;fill.clicked.connect(()=>{try{surface.engine.fill_address(UrlResolver.origin(surface.url),record.folder);close();}catch(Error e){EngineDialogs.show_error(this,e.message);}});row.add_suffix(fill);}list.append(row);}return Source.REMOVE;});});}
        private void edit(Record? record){
            var dialog=new Adw.Dialog();dialog.title=_("Address Profile");dialog.content_width=500;dialog.content_height=650;var layout=new Adw.ToolbarView();var header=new Adw.HeaderBar();var save=new Gtk.Button.with_label(_("Save"));header.pack_end(save);layout.add_top_bar(header);var fields=new Gtk.Box(Gtk.Orientation.VERTICAL,4);var title=new Adw.EntryRow();title.title=_("Profile Name");fields.append(title);var entries=new Gee.HashMap<string,Adw.EntryRow>();
            Json.Object? data=null;if(record!=null)try{var parser=new Json.Parser();parser.load_from_data(record.folder);data=parser.get_root().get_object();title.text=record.title;}catch(Error e){}
            foreach(string key in new string[]{"name","organization","street-address","address-line1","address-line2","address-level2","address-level1","postal-code","country","tel","email"}){var entry=new Adw.EntryRow();entry.title=key;if(data!=null && data.has_member(key))entry.text=data.get_string_member(key);entries[key]=entry;fields.append(entry);}var scroll=new Gtk.ScrolledWindow();scroll.child=fields;layout.content=scroll;dialog.child=layout;
            save.clicked.connect(()=>{var b=new Json.Builder();b.begin_object();foreach(string key in entries.keys){b.set_member_name(key);b.add_string_value(entries[key].text);}b.end_object();var g=new Json.Generator();g.set_root(b.get_root());string id=record==null?Uuid.string_random():record.url,name=title.text,text=g.to_data(null);app.storage.run((store)=>{store.save_address(id,name,text);Idle.add(()=>{refresh();return Source.REMOVE;});});dialog.close();});dialog.present(this);
        }
    }
}
