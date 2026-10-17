namespace MajorisBrowser {
    public class CredentialDialog : Adw.Dialog {
        private CredentialStore store;
        private Gtk.Entry username=new Gtk.Entry();
        private Gtk.PasswordEntry password=new Gtk.PasswordEntry();
        private Gtk.Label status=new Gtk.Label("");
        private string origin;
        private MajorisCef.View engine;
        public CredentialDialog (string origin,MajorisCef.View engine) {
            this.origin=origin;this.engine=engine;store=new CredentialStore("browser");
            title=_("Site Password");content_width=420;
            var layout=new Adw.ToolbarView();layout.add_top_bar(new Adw.HeaderBar());
            var box=new Gtk.Box(Gtk.Orientation.VERTICAL,12);box.margin_start=18;box.margin_end=18;box.margin_top=12;box.margin_bottom=18;
            box.append(new Gtk.Label(origin));username.placeholder_text=_("Username");password.show_peek_icon=true;box.append(username);box.append(password);box.append(status);status.wrap=true;
            var buttons=new Gtk.Box(Gtk.Orientation.HORIZONTAL,6);box.append(buttons);
            var save=new Gtk.Button.with_label(_("Save / Update"));buttons.append(save);save.clicked.connect(()=>operate.begin("save"));
            var fill=new Gtk.Button.with_label(_("Fill"));buttons.append(fill);fill.clicked.connect(()=>operate.begin("fill"));
            var remove=new Gtk.Button.with_label(_("Delete"));buttons.append(remove);remove.clicked.connect(()=>operate.begin("delete"));
            layout.content=box;child=layout;closed.connect(()=>password.text="");
        }
        private async void operate (string operation) {
            try{
                if(operation=="save"){yield store.save(origin,username.text,password.text);password.text="";status.label=_("Saved in Secret Service.");}
                else if(operation=="delete"){yield store.remove(origin,username.text);password.text="";status.label=_("Credential deleted.");}
                else {
                    string? secret=yield store.lookup(origin,username.text);
                    if(secret==null){status.label=_("No credential for this username.");return;}
                    engine.autofill(origin,username.text,secret);Secret.password_wipe(secret);close();
                }
            }catch(Error e){status.label=e.message;}
        }
    }
}
