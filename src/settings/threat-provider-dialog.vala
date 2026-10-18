namespace MajorisBrowser {
    public class ThreatProviderDialog : Adw.AlertDialog {
        public ThreatProviderDialog(Application app){
            heading=_("Threat Protection Service");
            body=_("A managed service must be authorised and provisioned by Majoris; ordinary users do not need their own Cloud account. Direct Google Web Risk is an advanced account-owner option. Enabling sends full destination URLs, including query strings and authentication URLs, from Browser, private windows and installed apps to the selected service and Google. Fragments and embedded credentials are excluded. Review the operator's privacy policy. Failed checks block navigation. Restart all Browser and app processes to apply.");
            var box=new Gtk.Box(Gtk.Orientation.VERTICAL,12);
            var notice=new Gtk.Label(_("Google Web Risk protection cannot be guaranteed. Unsafe sites may be missed and safe sites misidentified."));notice.wrap=true;box.append(notice);
            var mode=new Gtk.DropDown.from_strings({_("Direct Google Web Risk (account owner)"),_("Authorised Majoris managed service")});mode.selected=app.preferences.get_boolean("web-risk-managed")?1:0;box.append(mode);
            var endpoint=new Gtk.Entry();endpoint.placeholder_text=_("Managed HTTPS endpoint supplied by Majoris");endpoint.text=app.preferences.get_string("managed-threat-endpoint");endpoint.visible=mode.selected==1;mode.notify["selected"].connect(()=>{endpoint.visible=mode.selected==1;});box.append(endpoint);
            var key=new Gtk.PasswordEntry();key.placeholder_text=_("API key or per-installation token (blank keeps the stored secret)");key.show_peek_icon=true;box.append(key);
            var consent=new Gtk.CheckButton.with_label(_("I consent to sending these URLs to the selected authorised service"));consent.active=WebRiskProvider.consent_matches(app.preferences.get_boolean("web-risk-consent"),mode.selected==1,endpoint.text,app.preferences.get_string("web-risk-consent-target"));box.append(consent);extra_child=box;mode.notify["selected"].connect(()=>{consent.active=false;});endpoint.changed.connect(()=>{consent.active=false;});
            add_response("cancel",_("Cancel"));add_response("remove",_("Disable and Remove Key"));add_response("save",_("Save for Next Restart"));set_default_response("cancel");
            response.connect((id)=>{if(id=="save" || id=="remove")save.begin(app,key,consent.active,id=="remove",mode.selected==1,endpoint.text.strip());});
        }
        private async void save(Application app,Gtk.PasswordEntry entry,bool consent,bool remove,bool managed,string endpoint){
            var secrets=new ThreatProviderSecret(managed?"managed-web-risk":"google-web-risk");
            try{
                if(remove){app.preferences.set_boolean("web-risk-consent",false);app.preferences.set_string("web-risk-consent-target","");yield secrets.remove();}
                else{
                    if(managed)WebRiskProvider.validate_managed_endpoint(endpoint);
                    if(entry.text!="")yield secrets.save(entry.text);
                    else if(consent){var cancel=new Cancellable();string? existing=yield secrets.load(cancel);if(existing==null || existing=="")throw new IOError.NOT_FOUND(_("Store an API key before enabling Web Risk."));Secret.password_wipe(existing);}
                    app.preferences.set_string("managed-threat-endpoint",endpoint);app.preferences.set_boolean("web-risk-managed",managed);app.preferences.set_string("web-risk-consent-target",consent?(managed?endpoint:"google-web-risk"):"");app.preferences.set_boolean("web-risk-consent",consent);
                }
            }catch(Error e){EngineDialogs.show_error(app.active_window,_("Provider settings could not be saved. Check the endpoint, stored credential and that Secret Service is available and unlocked."));}
            entry.text="";
        }
    }
}
