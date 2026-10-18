namespace MajorisBrowser {
    public class CredentialController : Object {
        private BrowserSurface surface;
        private Application app;
        private CredentialStore secrets;
        private string profile;
        private bool prompting;
        private bool processing;
        private string? pending;
        private uint expiry;
        public CredentialController(Application app,BrowserSurface surface,string profile){
            this.app=app;this.surface=surface;this.profile=profile;secrets=new CredentialStore(profile);
            surface.changed.connect((kind,value)=>{
                if(kind=="credential-submit"){clear_pending();pending=value.dup();expiry=Timeout.add_seconds(60,()=>{expiry=0;clear_pending();return Source.REMOVE;});}
                if(kind=="credential-cancelled")clear_pending();
                if(kind=="credential-complete" && pending!=null){string captured=pending.dup();clear_pending();submitted.begin(captured,value);}
                if(kind=="credential-form")fill.begin(value);
            });
            surface.notify["closed"].connect(()=>{if(surface.closed)clear_pending();});
        }
        private void clear_pending(){if(expiry!=0){Source.remove(expiry);expiry=0;}if(pending!=null){Secret.password_wipe(pending);pending=null;}}
        private async bool blocked(string origin){bool result=true;SourceFunc resume=blocked.callback;app.storage.run((store)=>{try{result=store.password_blocked(profile,origin);}catch(Error e){result=true;}Idle.add((owned)resume);});yield;return result;}
        private bool same_site(string origin){try{return !surface.closed && UrlResolver.origin(surface.url)==UrlResolver.origin(origin);}catch(Error e){return false;}}
        private async void fill(string origin){
            try{
                if(yield blocked(origin))return;var users=yield secrets.usernames(origin);if(!same_site(origin) || users.size==0 || prompting)return;
                if(users.size==1){string? password=yield secrets.lookup(origin,users[0]);if(password!=null){if(same_site(origin))surface.engine.autofill(origin,users[0],password);Secret.password_wipe(password);}return;}
                prompting=true;var dialog=new Adw.AlertDialog(_("Choose a Saved Login"),origin);var selection=new Gtk.DropDown.from_strings(users.to_array());dialog.extra_child=selection;dialog.add_response("cancel",_("Cancel"));dialog.add_response("fill",_("Fill"));
                dialog.response.connect((id)=>{prompting=false;if(id=="fill" && same_site(origin))fill_user.begin(origin,users[(int)selection.selected]);});dialog.present(surface);
            }catch(Error e){/* An unavailable or locked keyring must not break navigation. */}
        }
        private async void fill_user(string origin,string username){try{string? password=yield secrets.lookup(origin,username);if(password!=null){if(same_site(origin))surface.engine.autofill(origin,username,password);Secret.password_wipe(password);}}catch(Error e){EngineDialogs.show_error(surface,e.message);}}
        private async void submitted(string text,string completed_origin){
            if(processing || prompting){Secret.password_wipe(text);return;}processing=true;
            string password="";
            try{
                var parser=new Json.Parser();parser.load_from_data(text);var value=parser.get_root().get_object();string origin=UrlResolver.origin(value.get_string_member("origin")),username=value.get_string_member("username");password=value.get_string_member("password");
                if(origin!=UrlResolver.origin(completed_origin)){Secret.password_wipe(password);return;}
                if(password=="" || prompting || yield blocked(origin)){Secret.password_wipe(password);return;}
                string? old=yield secrets.lookup(origin,username);bool update=old!=null;
                if(old==password){Secret.password_wipe(old);Secret.password_wipe(password);return;}if(old!=null)Secret.password_wipe(old);
                if(!same_site(origin)){Secret.password_wipe(password);return;}
                prompting=true;var dialog=new Adw.AlertDialog(update?_("Update Saved Password?"):_("Save Password?"),origin+"\n"+username);dialog.add_response("cancel",_("Not Now"));dialog.add_response("never",_("Never for This Site"));dialog.add_response("save",update?_("Update"):_("Save"));dialog.close_response="cancel";
                string pending=password;password="";
                dialog.response.connect((id)=>{prompting=false;if(id=="never")app.storage.run((store)=>store.never_save(profile,origin,true));if(id=="save")save.begin(origin,username,pending);else Secret.password_wipe(pending);});
                ulong closing=surface.notify["closed"].connect(()=>{if(surface.closed)dialog.force_close();});dialog.closed.connect(()=>surface.disconnect(closing));dialog.present(surface);
            }catch(Error e){if(password!="")Secret.password_wipe(password);}finally{processing=false;Secret.password_wipe(text);}
        }
        private async void save(string origin,string username,string password){try{if(!(yield blocked(origin)) && same_site(origin))yield secrets.save(origin,username,password);}catch(Error e){if(!surface.closed)EngineDialogs.show_error(surface,e.message);}finally{Secret.password_wipe(password);}}
    }
}
