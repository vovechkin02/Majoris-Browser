namespace MajorisBrowser {
    public class CertificateDialog : Adw.Dialog {
        public CertificateDialog(string text){
            title=_("Connection Certificate");content_width=650;content_height=600;var layout=new Adw.ToolbarView();layout.add_top_bar(new Adw.HeaderBar());var list=new Gtk.ListBox();list.selection_mode=Gtk.SelectionMode.NONE;list.add_css_class("boxed-list");var box=new Gtk.Box(Gtk.Orientation.VERTICAL,12);box.margin_start=16;box.margin_end=16;box.margin_top=16;box.margin_bottom=16;box.append(list);
            try{
                var parser=new Json.Parser();parser.load_from_data(text);var data=parser.get_root().get_object();
                if(!data.has_member("hostname"))throw new IOError.NOT_FOUND(_("No connection certificate information is available."));
                add_row(list,_("Hostname"),data.get_string_member("hostname"));add_row(list,_("Connection"),data.get_boolean_member("secure")?_("Chromium verified TLS without mixed-content warnings"):_("Not verified as a secure TLS connection"));
                add_row(list,_("Certificate / Content Status"),"%d / %d".printf((int)data.get_int_member("status"),(int)data.get_int_member("contentStatus")));
                if(data.get_string_member("errors")!="")add_row(list,_("Verification Errors"),data.get_string_member("errors"));
                if(data.has_member("subject")){
                    add_row(list,_("Subject"),data.get_string_member("subject"));add_row(list,_("Issuer"),data.get_string_member("issuer"));
                    int64 from=(int64)data.get_double_member("validFrom"),until=(int64)data.get_double_member("validUntil");add_row(list,_("Valid From"),from==0?_("Unavailable"):new DateTime.from_unix_local(from).format("%c %Z"));add_row(list,_("Valid Until"),until==0?_("Unavailable"):new DateTime.from_unix_local(until).format("%c %Z"));
                    var chain=new Adw.ExpanderRow();chain.title=_("PEM Certificate Chain");var view=new Gtk.TextView();view.editable=false;view.monospace=true;view.wrap_mode=Gtk.WrapMode.CHAR;view.buffer.text=data.get_string_member("pem");chain.add_row(view);list.append(chain);
                }
            }catch(Error e){var label=new Gtk.Label(e.message);label.wrap=true;box.append(label);}
            var scroll=new Gtk.ScrolledWindow();scroll.child=box;layout.content=scroll;child=layout;
        }
        private void add_row(Gtk.ListBox list,string label,string value){var row=new Adw.ActionRow();row.use_markup=false;row.title=label;row.subtitle=value;row.subtitle_selectable=true;list.append(row);}
    }
}
