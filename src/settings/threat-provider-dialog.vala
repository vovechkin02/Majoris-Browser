namespace MajorisBrowser {
    public class ThreatProviderDialog : Adw.AlertDialog {
        public ThreatProviderDialog(Application app){
            heading=_("Google Web Risk");
            body=_("Requires your authorised Google Cloud Web Risk account, enabled API and applicable billing/terms. Enabling sends full destination URLs, including query strings, from Browser, private windows and installed apps to Google. Fragments and embedded credentials are excluded. This checks navigation URLs, not downloaded files. Unknown or failed checks block navigation. Restart all Browser and app processes to apply.");
            var box=new Gtk.Box(Gtk.Orientation.VERTICAL,12);
            var notice=new Gtk.Label(_("Google Web Risk protection cannot be guaranteed. Unsafe sites may be missed and safe sites misidentified."));notice.wrap=true;box.append(notice);
            var key=new Gtk.PasswordEntry();key.placeholder_text=_("New API key (blank keeps the stored key)");key.show_peek_icon=true;box.append(key);
            var consent=new Gtk.CheckButton.with_label(_("I have an authorised account and consent to sending these URLs"));consent.active=app.preferences.get_boolean("web-risk-consent");box.append(consent);extra_child=box;
            add_response("cancel",_("Cancel"));add_response("remove",_("Disable and Remove Key"));add_response("save",_("Save for Next Restart"));set_default_response("cancel");
            response.connect((id)=>{if(id=="save" || id=="remove")save.begin(app,key,consent.active,id=="remove");});
        }
        private async void save(Application app,Gtk.PasswordEntry entry,bool consent,bool remove){
            var secrets=new ThreatProviderSecret();
            try{
                if(remove){app.preferences.set_boolean("web-risk-consent",false);yield secrets.remove();}
                else{
                    if(entry.text!="")yield secrets.save(entry.text);
                    else if(consent){var cancel=new Cancellable();string? existing=yield secrets.load(cancel);if(existing==null || existing=="")throw new IOError.NOT_FOUND(_("Store an API key before enabling Web Risk."));Secret.password_wipe(existing);}
                    app.preferences.set_boolean("web-risk-consent",consent);
                }
            }catch(Error e){EngineDialogs.show_error(app.active_window,_("Provider settings could not be saved. Check that Secret Service is available and unlocked."));}
            entry.text="";
        }
    }
}
