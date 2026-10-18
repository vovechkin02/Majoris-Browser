namespace MajorisBrowser {
    public interface ShellIntegration : Object {
        public abstract bool set_pinned (string desktop_id,bool pinned);
        public abstract bool is_pinned(string desktop_id);
    }
    public class DesktopShellIntegration : Object, ShellIntegration {
        public bool is_pinned(string desktop_id){
            var source=SettingsSchemaSource.get_default();var schema=source.lookup("org.gnome.shell",true);
            if(schema==null || !schema.has_key("favorite-apps"))return false;
            foreach(string item in new Settings.full(schema,null,null).get_strv("favorite-apps"))if(item==desktop_id)return true;return false;
        }
        public bool set_pinned (string desktop_id,bool pinned) {
            var source = SettingsSchemaSource.get_default ();
            var schema = source.lookup ("org.gnome.shell",true);
            if (schema == null || !schema.has_key ("favorite-apps")) return false;
            var settings = new Settings.full (schema,null,null);
            var apps = new Gee.ArrayList<string> (); apps.add_all_array (settings.get_strv ("favorite-apps"));
            if (pinned && !apps.contains (desktop_id)) apps.add (desktop_id);
            if (!pinned) apps.remove (desktop_id);
            return settings.set_strv ("favorite-apps",apps.to_array ());
        }
    }
}
