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
            int current=version.column_int(0);
            if (current > 4) throw new BrowserError.STORAGE ("Database is newer than this Browser");
            if(current==0)exec ("BEGIN IMMEDIATE; CREATE TABLE IF NOT EXISTS history(id INTEGER PRIMARY KEY,url TEXT NOT NULL,title TEXT NOT NULL,visited INTEGER NOT NULL); CREATE TABLE IF NOT EXISTS bookmarks(id INTEGER PRIMARY KEY,url TEXT UNIQUE NOT NULL,title TEXT NOT NULL,folder TEXT NOT NULL DEFAULT ''); CREATE TABLE IF NOT EXISTS sessions(window_id TEXT PRIMARY KEY,state TEXT NOT NULL); CREATE TABLE IF NOT EXISTS webapps(id TEXT PRIMARY KEY,metadata TEXT NOT NULL); CREATE TABLE IF NOT EXISTS permissions(profile TEXT,origin TEXT,kind TEXT,value INTEGER,PRIMARY KEY(profile,origin,kind)); PRAGMA user_version=1; COMMIT;");
            if(current<2)exec("BEGIN IMMEDIATE; CREATE TABLE bookmark_folders(name TEXT PRIMARY KEY); INSERT OR IGNORE INTO bookmark_folders SELECT DISTINCT folder FROM bookmarks WHERE folder<>''; CREATE TABLE browser_snapshot(id INTEGER PRIMARY KEY CHECK(id=1),generation INTEGER NOT NULL,state TEXT NOT NULL,clean INTEGER NOT NULL); CREATE TABLE downloads(id TEXT PRIMARY KEY,metadata TEXT NOT NULL); CREATE TABLE never_save(profile TEXT,origin TEXT,PRIMARY KEY(profile,origin)); ALTER TABLE permissions ADD COLUMN expires INTEGER NOT NULL DEFAULT 0; PRAGMA user_version=2; COMMIT;");
            if(current<3)exec("BEGIN IMMEDIATE; CREATE TABLE addresses(id TEXT PRIMARY KEY,title TEXT NOT NULL,fields TEXT NOT NULL); PRAGMA user_version=3; COMMIT;");
            if(current<4)exec("BEGIN IMMEDIATE; CREATE TABLE bookmark_bar_order(item TEXT PRIMARY KEY,rank INTEGER NOT NULL); PRAGMA user_version=4; COMMIT;");
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
            create_folder(folder);
            var s = statement ("INSERT INTO bookmarks(url,title,folder) VALUES(?,?,?) ON CONFLICT(url) DO UPDATE SET title=excluded.title,folder=excluded.folder");
            s.bind_text (1,url); s.bind_text (2,title); s.bind_text (3,folder); finish (s);
        }
        public Gee.ArrayList<Record> search (bool bookmarks, string query = "", int limit = 200) throws Error {
            var s = statement (bookmarks ? "SELECT id,url,title,folder FROM bookmarks WHERE instr(lower(title||url),lower(?))>0 ORDER BY title LIMIT ?" : "SELECT id,url,title,'' FROM history WHERE instr(lower(title||url),lower(?))>0 ORDER BY visited DESC,id DESC LIMIT ?");
            s.bind_text (1,query);
            s.bind_int (2,limit < 0 ? -1 : int.min(limit,10000));
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
        public void edit_bookmark(int64 id,string url,string title,string folder) throws Error {
            UrlResolver.web_uri(url);create_folder(folder);var s=statement("UPDATE bookmarks SET url=?,title=?,folder=? WHERE id=?");s.bind_text(1,url);s.bind_text(2,title);s.bind_text(3,folder);s.bind_int64(4,id);finish(s);
        }
        public void create_folder(string name) throws Error {if(name=="")return;var s=statement("INSERT OR IGNORE INTO bookmark_folders VALUES(?)");s.bind_text(1,name);finish(s);}
        public Gee.ArrayList<string> folders() throws Error {var result=new Gee.ArrayList<string>();var s=statement("SELECT name FROM bookmark_folders ORDER BY name");while(s.step()==Sqlite.ROW)result.add(s.column_text(0));return result;}
        public void rename_folder(string from,string to) throws Error {
            if(from==to)return;
            if(to.strip()=="")throw new BrowserError.STORAGE("Folder name is empty");
            exec("BEGIN IMMEDIATE");try{create_folder(to);var s=statement("UPDATE bookmarks SET folder=? WHERE folder=?");s.bind_text(1,to);s.bind_text(2,from);finish(s);s=statement("DELETE FROM bookmark_folders WHERE name=?");s.bind_text(1,from);finish(s);s=statement("INSERT OR IGNORE INTO bookmark_bar_order SELECT ?,rank FROM bookmark_bar_order WHERE item=?");s.bind_text(1,"folder:"+to);s.bind_text(2,"folder:"+from);finish(s);s=statement("DELETE FROM bookmark_bar_order WHERE item=?");s.bind_text(1,"folder:"+from);finish(s);exec("COMMIT");}catch(Error e){exec("ROLLBACK");throw e;}
        }
        public void delete_folder(string name) throws Error {
            exec("BEGIN IMMEDIATE");try{var s=statement("UPDATE bookmarks SET folder='' WHERE folder=?");s.bind_text(1,name);finish(s);s=statement("DELETE FROM bookmark_folders WHERE name=?");s.bind_text(1,name);finish(s);exec("COMMIT");}catch(Error e){exec("ROLLBACK");throw e;}
        }
        public void snapshot(int64 generation,string state,bool clean) throws Error {
            var s=statement("INSERT INTO browser_snapshot VALUES(1,?,?,?) ON CONFLICT(id) DO UPDATE SET generation=excluded.generation,state=excluded.state,clean=excluded.clean WHERE excluded.generation>browser_snapshot.generation");s.bind_int64(1,generation);s.bind_text(2,state);s.bind_int(3,clean?1:0);finish(s);
        }
        public string? snapshot_state() throws Error {var s=statement("SELECT state FROM browser_snapshot WHERE id=1");return s.step()==Sqlite.ROW?s.column_text(0):null;}
        public bool snapshot_clean() throws Error {var s=statement("SELECT clean FROM browser_snapshot WHERE id=1");return s.step()!=Sqlite.ROW || s.column_int(0)==1;}
        public void permission(string profile,string origin,string kind,int value,int64 expires=0) throws Error {
            origin=UrlResolver.origin(origin);var s=statement("INSERT INTO permissions VALUES(?,?,?,?,?) ON CONFLICT(profile,origin,kind) DO UPDATE SET value=excluded.value,expires=excluded.expires");s.bind_text(1,profile);s.bind_text(2,origin);s.bind_text(3,kind);s.bind_int(4,value);s.bind_int64(5,expires);finish(s);
        }
        public int permission_value(string profile,string origin,string kind) throws Error {
            var s=statement("SELECT value,expires FROM permissions WHERE profile=? AND origin=? AND kind=?");s.bind_text(1,profile);s.bind_text(2,UrlResolver.origin(origin));s.bind_text(3,kind);
            if(s.step()!=Sqlite.ROW)return 0;int64 expires=s.column_int64(1);return expires!=0 && expires<=new DateTime.now_utc().to_unix()?0:s.column_int(0);
        }
        public void reset_permissions(string profile,string origin) throws Error {var s=statement("DELETE FROM permissions WHERE profile=? AND origin=?");s.bind_text(1,profile);s.bind_text(2,UrlResolver.origin(origin));finish(s);}
        public void save_download(string id,string metadata) throws Error {var s=statement("INSERT INTO downloads VALUES(?,?) ON CONFLICT(id) DO UPDATE SET metadata=excluded.metadata");s.bind_text(1,id);s.bind_text(2,metadata);finish(s);}
        public Gee.ArrayList<string> download_records() throws Error {var rows=new Gee.ArrayList<string>();var s=statement("SELECT metadata FROM downloads ORDER BY rowid DESC");while(s.step()==Sqlite.ROW)rows.add(s.column_text(0));return rows;}
        public void remove_download(string id) throws Error {var s=statement("DELETE FROM downloads WHERE id=?");s.bind_text(1,id);finish(s);}
        public void never_save(string profile,string origin,bool disabled) throws Error {var s=statement(disabled?"INSERT OR IGNORE INTO never_save VALUES(?,?)":"DELETE FROM never_save WHERE profile=? AND origin=?");s.bind_text(1,profile);s.bind_text(2,UrlResolver.origin(origin));finish(s);}
        public bool password_blocked(string profile,string origin) throws Error {var s=statement("SELECT 1 FROM never_save WHERE profile=? AND origin=?");s.bind_text(1,profile);s.bind_text(2,UrlResolver.origin(origin));return s.step()==Sqlite.ROW;}
        public Gee.ArrayList<Record> site_policies(string profile,bool passwords=false) throws Error {
            var rows=new Gee.ArrayList<Record>();var s=statement(passwords?"SELECT origin,'never save','' FROM never_save WHERE profile=? ORDER BY origin":"SELECT origin,kind,CAST(value AS TEXT) FROM permissions WHERE profile=? ORDER BY origin,kind");s.bind_text(1,profile);while(s.step()==Sqlite.ROW)rows.add(new Record(0,s.column_text(0),s.column_text(1),s.column_text(2)));return rows;
        }
        public void save_address(string id,string title,string fields) throws Error {if(fields.length>16384)throw new BrowserError.STORAGE("Address profile is too large");var s=statement("INSERT INTO addresses VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET title=excluded.title,fields=excluded.fields");s.bind_text(1,id);s.bind_text(2,title);s.bind_text(3,fields);finish(s);}
        public Gee.ArrayList<Record> addresses() throws Error {var rows=new Gee.ArrayList<Record>();var s=statement("SELECT id,title,fields FROM addresses ORDER BY title");while(s.step()==Sqlite.ROW)rows.add(new Record(0,s.column_text(0),s.column_text(1),s.column_text(2)));return rows;}
        public void delete_address(string id) throws Error {var s=statement("DELETE FROM addresses WHERE id=?");s.bind_text(1,id);finish(s);}
        public void imported_visit(string url,string title,int64 visited) throws Error {UrlResolver.web_uri(url);var s=statement("INSERT INTO history(url,title,visited) VALUES(?,?,?)");s.bind_text(1,url);s.bind_text(2,title);s.bind_int64(3,int64.max(0,int64.min(visited,new DateTime.now_utc().to_unix())));finish(s);}
        public Gee.ArrayList<Record> bar_items() throws Error {
            var rows=new Gee.ArrayList<Record>();var s=statement("SELECT b.id,b.url,b.title,'bookmark:'||b.id AS item,COALESCE(o.rank,1000000+b.id) AS ordering FROM bookmarks b LEFT JOIN bookmark_bar_order o ON o.item='bookmark:'||b.id WHERE b.folder='' UNION ALL SELECT 0,'',f.name,'folder:'||f.name AS item,COALESCE(o.rank,2000000+f.rowid) AS ordering FROM bookmark_folders f LEFT JOIN bookmark_bar_order o ON o.item='folder:'||f.name ORDER BY ordering,item");while(s.step()==Sqlite.ROW)rows.add(new Record(s.column_int64(0),s.column_text(1),s.column_text(2),s.column_text(3)));return rows;
        }
        public void reorder_bar(string item,string before) throws Error {
            var rows=bar_items();Record? moving=null;foreach(var row in rows)if(row.folder==item){moving=row;break;}if(moving==null || item==before)return;rows.remove(moving);int index=rows.size;for(int i=0;i<rows.size;i++)if(rows[i].folder==before){index=i;break;}rows.insert(index,moving);
            exec("BEGIN IMMEDIATE");try{for(int i=0;i<rows.size;i++){var s=statement("INSERT INTO bookmark_bar_order VALUES(?,?) ON CONFLICT(item) DO UPDATE SET rank=excluded.rank");s.bind_text(1,rows[i].folder);s.bind_int(2,i);finish(s);}exec("COMMIT");}catch(Error e){exec("ROLLBACK");throw e;}
        }
    }
}
