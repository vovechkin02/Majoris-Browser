namespace MajorisBrowser {
    public class TabState : Object {
        public string url;
        public bool pinned;
        public TabState (string url, bool pinned = false) { this.url = url; this.pinned = pinned; }
    }
    public class TabModel : Object {
        public Gee.ArrayList<TabState> tabs = new Gee.ArrayList<TabState> ();
        private Gee.ArrayList<TabState> closed = new Gee.ArrayList<TabState> ();
        public void add (TabState tab) { if (tab.pinned) tabs.insert (0,tab); else tabs.add (tab); }
        public void close (int index) { closed.add (tabs.remove_at (index)); if (closed.size > 25) closed.remove_at (0); }
        public TabState? reopen () { if (closed.size == 0) return null; var t = closed.remove_at (closed.size-1); add (t); return t; }
        public bool move (int from, int to) {
            if (from < 0 || to < 0 || from >= tabs.size || to >= tabs.size || tabs[from].pinned != tabs[to].pinned) return false;
            var t = tabs.remove_at (from); tabs.insert (to,t); return true;
        }
    }
}
