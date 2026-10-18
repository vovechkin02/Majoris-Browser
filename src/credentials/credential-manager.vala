namespace MajorisBrowser {
    public class CredentialManager : Adw.Dialog {
        private CredentialStore secrets;
        private Gtk.ListBox list=new Gtk.ListBox();
        private Gtk.SearchEntry search=new Gtk.SearchEntry();
        private Gee.ArrayList<Record> entries=new Gee.ArrayList<Record>();
        private string profile;
        private MajorisCef.View? view;
        public CredentialManager(string profile="browser",MajorisCef.View? view=null){
            this.profile=profile;this.view=view;secrets=new CredentialStore(profile);title=_("Saved Passwords");content_width=650;content_height=550;
            var layout=new Adw.ToolbarView();layout.add_top_bar(new Adw.HeaderBar());var box=new Gtk.Box(Gtk.Orientation.VERTICAL,8);box.append(search);var scroll=new Gtk.ScrolledWindow();scroll.vexpand=true;scroll.child=list;box.append(scroll);layout.content=box;child=layout;search.search_changed.connect(render);refresh.begin();
        }
        private async void refresh(){try{entries=yield secrets.entries();render();}catch(Error e){EngineDialogs.show_error(this,e.message);}}
        private void render(){
            while(list.get_first_child()!=null)list.remove(list.get_first_child());
            foreach(var record in entries){if(!(record.url+record.title).down().contains(search.text.down()))continue;var row=new Adw.ActionRow();row.use_markup=false;row.title=record.url;row.subtitle=record.title;
                if(view!=null){var fill=new Gtk.Button.with_label(_("Fill"));fill.valign=Gtk.Align.CENTER;fill.clicked.connect(()=>fill_secret.begin(record));row.add_suffix(fill);}
                var reveal=new Gtk.Button.from_icon_name("view-reveal-symbolic");reveal.tooltip_text=_("Authenticate and View / Update");reveal.valign=Gtk.Align.CENTER;row.add_suffix(reveal);reveal.clicked.connect(()=>reveal_secret.begin(record));
                var remove=new Gtk.Button.from_icon_name("user-trash-symbolic");remove.valign=Gtk.Align.CENTER;row.add_suffix(remove);remove.clicked.connect(()=>{var confirm=new Adw.AlertDialog(_("Delete Saved Password?"),record.url+"\n"+record.title);confirm.add_response("cancel",_("Cancel"));confirm.add_response("delete",_("Delete"));confirm.set_response_appearance("delete",Adw.ResponseAppearance.DESTRUCTIVE);confirm.response.connect((id)=>{if(id=="delete")remove_secret.begin(record);});confirm.present(this);});list.append(row);
            }
        }
        private async void remove_secret(Record record){try{yield secrets.remove(record.url,record.title);yield refresh();}catch(Error e){EngineDialogs.show_error(this,e.message);}}
        private async void fill_secret(Record record){
            try{string? password=yield secrets.lookup(record.url,record.title);if(password==null || view==null)return;ulong handler=0;handler=view.event.connect((kind,value)=>{if(kind=="credential-filled" || kind=="credential-fill-refused" || kind=="closed"){view.disconnect(handler);if(kind=="credential-filled")close();else if(kind!="closed")EngineDialogs.show_error(this,_("The current secure page does not contain a matching login form for this origin."));}});view.autofill(record.url,record.title,password);Secret.password_wipe(password);}catch(Error e){EngineDialogs.show_error(this,e.message);}
        }
        private async void reveal_secret(Record record){
            try{
                var bus=yield Bus.get(BusType.SYSTEM,null);var subject=new VariantBuilder(new VariantType("a{sv}"));subject.add("{sv}","name",new Variant.string(bus.get_unique_name()));var details=new VariantBuilder(new VariantType("a{ss}"));
                var result=yield bus.call("org.freedesktop.PolicyKit1","/org/freedesktop/PolicyKit1/Authority","org.freedesktop.PolicyKit1.Authority","CheckAuthorization",new Variant("((s@a{sv})s@a{ss}us)","system-bus-name",subject.end(),"com.majoris.browser.reveal-credential",details.end(),(uint)1,""),new VariantType("((bba{ss}))"),DBusCallFlags.NONE,-1,null);
                if(!result.get_child_value(0).get_child_value(0).get_boolean())throw new IOError.PERMISSION_DENIED(_("Authentication was not granted."));
                string? password=yield secrets.lookup(record.url,record.title);if(password==null)return;
                var dialog=new Adw.AlertDialog(record.url,record.title);var field=new Gtk.PasswordEntry();field.text=password;field.show_peek_icon=true;Secret.password_wipe(password);dialog.extra_child=field;dialog.add_response("close",_("Close"));dialog.add_response("save",_("Update"));dialog.response.connect((id)=>{if(id=="save")update.begin(record,field.text);field.text="";});dialog.closed.connect(()=>field.text="");dialog.present(this);
            }catch(Error e){EngineDialogs.show_error(this,e.message);}
        }
        private async void update(Record record,string password){try{yield secrets.save(record.url,record.title,password);}catch(Error e){EngineDialogs.show_error(this,e.message);}finally{Secret.password_wipe(password);}}
    }
}
