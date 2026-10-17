namespace MajorisBrowser {
    public class PolicyDialog : Adw.Dialog {
        private Application app;
        private string profile;
        private Gtk.ListBox list=new Gtk.ListBox();
        public PolicyDialog(Application app,string profile="browser"){
            this.app=app;this.profile=profile;title=_("Site Permissions and Password Exceptions");content_width=650;content_height=600;var layout=new Adw.ToolbarView();layout.add_top_bar(new Adw.HeaderBar());var scroll=new Gtk.ScrolledWindow();scroll.child=list;layout.content=scroll;child=layout;refresh();
        }
        private void refresh(){app.storage.run((store)=>{var permissions=store.site_policies(profile);var exceptions=store.site_policies(profile,true);Idle.add(()=>{
            while(list.get_first_child()!=null)list.remove(list.get_first_child());
            foreach(var record in permissions){var row=new Adw.ComboRow();row.use_markup=false;row.title=record.url;row.subtitle=record.title;row.model=new Gtk.StringList({_("Ask"),_("Allow"),_("Block")});row.selected=int.parse(record.folder);row.notify["selected"].connect(()=>app.permissions.remember(profile,record.url,{record.title},(int)row.selected));list.append(row);}
            foreach(var record in exceptions){var row=new Adw.ActionRow();row.use_markup=false;row.title=record.url;row.subtitle=_("Never save passwords");var remove=new Gtk.Button.with_label(_("Remove Exception"));remove.valign=Gtk.Align.CENTER;row.add_suffix(remove);remove.clicked.connect(()=>{app.storage.run((store)=>{store.never_save(profile,record.url,false);Idle.add(()=>{refresh();return Source.REMOVE;});});});list.append(row);}return Source.REMOVE;
        });});}
    }
}
