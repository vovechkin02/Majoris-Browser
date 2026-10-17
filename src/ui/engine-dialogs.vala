namespace MajorisBrowser {
    public class EngineDialogs : Object {
        public static void attach (BrowserSurface surface, Gtk.Window window) {
            surface.engine.request.connect ((token,kind,origin,message) => {
                if (kind == "file" || kind == "download") {
                    choose_file.begin (surface,window,token,kind,message); return;
                }
                var dialog = new Adw.AlertDialog (origin,message);
                var entry = new Gtk.Entry ();
                if (kind == "prompt") dialog.extra_child = entry;
                dialog.add_response ("cancel",_("Cancel")); dialog.add_response ("accept",kind == "permission" ? _("Allow") : _("OK"));
                dialog.close_response = "cancel"; dialog.default_response = "cancel";
                dialog.response.connect ((response) => surface.engine.reply (token,response == "accept",entry.text));
                dialog.present (window);
            });
        }
        private static async void choose_file (BrowserSurface surface,Gtk.Window window,int token,string kind,string message) {
            var dialog = new Gtk.FileDialog ();
            try {
                File? selected;
                if (kind == "download") { dialog.initial_name = Path.get_basename (message); selected = yield dialog.save (window,null); }
                else selected = yield dialog.open (window,null);
                surface.engine.reply (token,true,selected.get_path ());
            } catch (Error e) { surface.engine.reply (token,false,""); }
        }
        public static void show_error (Gtk.Widget parent,string message) {
            var dialog = new Adw.AlertDialog (_("Browser"),message); dialog.add_response ("ok",_("OK")); dialog.present (parent);
        }
    }
}
