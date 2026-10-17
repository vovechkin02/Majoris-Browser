namespace MajorisBrowser {
    public class Record : Object {
        public int64 id;
        public string url;
        public string title;
        public string folder;
        public Record (int64 id, string url, string title, string folder = "") { this.id = id; this.url = url; this.title = title; this.folder = folder; }
    }
    // Each instance belongs to one thread. UI callers use StoreWorker below.
    public class Store : Object {
        private Sqlite.Database db;
        public Store (string path) throws Error {
            if (Sqlite.Database.open (path, out db) != Sqlite.OK) throw new BrowserError.STORAGE ("Cannot open database");
            db.busy_timeout (5000);
            exec ("PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON;");
            var version = statement ("PRAGMA user_version");
            version.step ();
            if (version.column_int (0) > 1) throw new BrowserError.STORAGE ("Database is newer than this Browser");
            exec ("BEGIN IMMEDIATE; CREATE TABLE IF NOT EXISTS history(id INTEGER PRIMARY KEY,url TEXT NOT NULL,title TEXT NOT NULL,visited INTEGER NOT NULL); CREATE TABLE IF NOT EXISTS bookmarks(id INTEGER PRIMARY KEY,url TEXT UNIQUE NOT NULL,title TEXT NOT NULL,folder TEXT NOT NULL DEFAULT ''); CREATE TABLE IF NOT EXISTS sessions(window_id TEXT PRIMARY KEY,state TEXT NOT NULL); CREATE TABLE IF NOT EXISTS webapps(id TEXT PRIMARY KEY,metadata TEXT NOT NULL); CREATE TABLE IF NOT EXISTS permissions(profile TEXT,origin TEXT,kind TEXT,value INTEGER,PRIMARY KEY(profile,origin,kind)); PRAGMA user_version=1; COMMIT;");
        }
        private void exec (string sql) throws Error {
            if (db.exec (sql) != Sqlite.OK) throw new BrowserError.STORAGE (db.errmsg ());
        }
        private Sqlite.Statement statement (string sql) throws Error {
            Sqlite.Statement s;
            if (db.prepare_v2 (sql, -1, out s) != Sqlite.OK) throw new BrowserError.STORAGE (db.errmsg ());
            return s;
        }
        private void finish (Sqlite.Statement s) throws Error {
            if (s.step () != Sqlite.DONE) throw new BrowserError.STORAGE (db.errmsg ());
        }
        public void visit (string url, string title, bool is_private = false) throws Error {
            if (is_private || !url.has_prefix ("http")) return;
            var s = statement ("INSERT INTO history(url,title,visited) VALUES(?,?,?)");
            s.bind_text (1,url); s.bind_text (2,title); s.bind_int64 (3,new DateTime.now_utc ().to_unix ()); finish (s);
        }
        public void bookmark (string url, string title, string folder = "") throws Error {
            UrlResolver.web_uri (url);
            var s = statement ("INSERT INTO bookmarks(url,title,folder) VALUES(?,?,?) ON CONFLICT(url) DO UPDATE SET title=excluded.title,folder=excluded.folder");
            s.bind_text (1,url); s.bind_text (2,title); s.bind_text (3,folder); finish (s);
        }
        public Gee.ArrayList<Record> search (bool bookmarks, string query = "") throws Error {
            var s = statement (bookmarks ? "SELECT id,url,title,folder FROM bookmarks WHERE instr(lower(title||url),lower(?))>0 ORDER BY title LIMIT 200" : "SELECT id,url,title,'' FROM history WHERE instr(lower(title||url),lower(?))>0 ORDER BY visited DESC,id DESC LIMIT 200");
            s.bind_text (1,query);
            var rows = new Gee.ArrayList<Record> ();
            int result;
            while ((result = s.step ()) == Sqlite.ROW) rows.add (new Record (s.column_int64 (0),s.column_text (1),s.column_text (2),s.column_text (3)));
            if (result != Sqlite.DONE) throw new BrowserError.STORAGE (db.errmsg ());
            return rows;
        }
        public void remove (bool bookmarks, int64 id) throws Error {
            var s = statement (bookmarks ? "DELETE FROM bookmarks WHERE id=?" : "DELETE FROM history WHERE id=?");
            s.bind_int64 (1,id); finish (s);
        }
        public void clear_history (int64 since = 0) throws Error {
            var s = statement ("DELETE FROM history WHERE visited>=?"); s.bind_int64 (1,since); finish (s);
        }
        public void save_session (string id, string state, bool is_private) throws Error {
            if (is_private) return;
            var s = statement ("INSERT INTO sessions VALUES(?,?) ON CONFLICT(window_id) DO UPDATE SET state=excluded.state");
            s.bind_text (1,id); s.bind_text (2,state); finish (s);
        }
        public string? session (string id) throws Error {
            var s = statement ("SELECT state FROM sessions WHERE window_id=?"); s.bind_text (1,id);
            return s.step () == Sqlite.ROW ? s.column_text (0) : null;
        }
        public void put_app (WebApp app) throws Error {
            var s = statement ("INSERT INTO webapps VALUES(?,?) ON CONFLICT(id) DO UPDATE SET metadata=excluded.metadata");
            s.bind_text (1,app.id); s.bind_text (2,app.serialize ()); finish (s);
        }
        public WebApp? get_app (string id) throws Error {
            var s = statement ("SELECT metadata FROM webapps WHERE id=?"); s.bind_text (1,id);
            return s.step () == Sqlite.ROW ? WebApp.deserialize (s.column_text (0)) : null;
        }
        public Gee.ArrayList<WebApp> apps () throws Error {
            var result = new Gee.ArrayList<WebApp> ();
            var s = statement ("SELECT metadata FROM webapps ORDER BY id");
            while (s.step () == Sqlite.ROW) result.add (WebApp.deserialize (s.column_text (0)));
            return result;
        }
        public void delete_app (string id) throws Error { var s = statement ("DELETE FROM webapps WHERE id=?"); s.bind_text (1,id); finish (s); }
    }
}
