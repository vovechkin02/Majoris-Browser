using MajorisBrowser;
void main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/urls/resolution", () => {
        assert (UrlResolver.resolve ("example.com") == "https://example.com");
        assert (UrlResolver.resolve ("hello world").contains ("hello%20world"));
        assert (UrlResolver.resolve ("localhost:8000") == "http://localhost:8000");
        assert (UrlResolver.resolve ("javascript:alert(1)").has_prefix ("https://duckduckgo.com/"));
    });
    Test.add_func ("/webapps/scope", () => {
        try {
            var p = new WebAppNavigationPolicy ("https://docs.google.com/spreadsheets/");
            assert (p.classify ("https://docs.google.com/spreadsheets/abc") == NavigationDecision.APP_SCOPE);
            assert (p.classify ("https://docs.google.com.evil.test/spreadsheets/") == NavigationDecision.EXTERNAL);
            assert (p.classify ("https://docs.google.com/spreadsheets-evil/") == NavigationDecision.EXTERNAL);
            assert (p.classify ("https://accounts.google.com/") == NavigationDecision.EXTERNAL);
            assert (p.classify ("javascript:alert(1)") == NavigationDecision.EXTERNAL);
        } catch (Error e) { error ("%s",e.message); }
    });
    Test.add_func ("/storage/migrations-private-and-sessions", () => {
        try {
            var s = new Store (":memory:");
            s.visit ("https://example.com", "Example");
            s.visit ("https://secret.test", "Private",true);
            assert (s.search (false).size == 1);
            s.bookmark ("https://example.com", "Example", "Work");
            s.bookmark ("https://example.com", "Updated", "Work");
            assert (s.search (true).size == 1);
            assert (s.search (true)[0].title == "Updated");
            s.save_session ("private","secret",true); assert (s.session ("private") == null);
            s.save_session ("normal","state",false); assert (s.session ("normal") == "state");
            s.clear_history (); assert (s.search (false).size == 0); assert (s.search (true).size == 1);
        } catch (Error e) { error ("%s",e.message); }
    });
    Test.add_func ("/profiles/isolated-paths", () => {
        try {
            var p = new ProfilePaths ("/tmp/majoris-test");
            var app = new WebApp ("Sheets", "https://docs.google.com/spreadsheets/");
            assert (p.browser_context != p.webapp_context (app.id));
            assert (p.webapp_context (app.id).has_prefix (p.cef_root + "/webapps/"));
            bool rejected = false; try { p.webapp_context ("../../browser"); } catch (Error e) { rejected = true; } assert (rejected);
            var s = new Store (":memory:"); s.put_app (app);
            assert (s.get_app (app.id).application_id == app.application_id);
            assert (s.get_app (app.id).scope == app.scope);
        } catch (Error e) { error ("%s",e.message); }
    });
    Test.add_func ("/tabs/reopen-and-pins", () => {
        var m = new TabModel (); m.add (new TabState ("one",true)); m.add (new TabState ("two")); m.add (new TabState ("three"));
        assert (!m.move (0,1)); assert (m.move (1,2)); assert (m.tabs[1].url == "three");
        m.close (1); assert (m.reopen ().url == "three");
    });
    Test.add_func ("/webapps/authentication", () => {
        try{
            var policy=new AuthenticationPolicy("https://docs.google.com/spreadsheets/");
            assert(policy.is_candidate("https://accounts.google.com/ServiceLogin?continue=https%3A%2F%2Fdocs.google.com%2Fspreadsheets%2F"));
            assert(!policy.is_candidate("https://accounts.google.com/ServiceLogin?continue=https%3A%2F%2Fevil.test%2F"));
            assert(!policy.is_candidate("https://accounts.google.com.evil.test/?continue=https%3A%2F%2Fdocs.google.com%2Fspreadsheets%2F"));
            assert(!policy.is_candidate("https://login.microsoftonline.com/authorize?redirect_uri=https%3A%2F%2Fdocs.google.com%2Fspreadsheets%2F&state=x&client_id=x"));
        }catch(Error e){error("%s",e.message);}
    });
    Test.add_func("/webapps/manifest",()=>{
        try{
            assert(ManifestDiscovery.find("<link href='/app.json' rel='manifest'>","https://example.com/")=="https://example.com/app.json");
            assert(ManifestDiscovery.find("<link rel=manifest href=https://evil.test/app.json>","https://example.com/")==null);
            var app=WebApp.from_manifest("{\"name\":\"Example App\",\"start_url\":\"/work/start\",\"scope\":\"/work/\"}","https://example.com/app.json","https://example.com/","Fallback");
            assert(app.name=="Example App");assert(app.start_url=="https://example.com/work/start");assert(app.scope=="https://example.com/work/");
            bool invalid=false;
            try{WebApp.from_manifest("{\"start_url\":\"https://evil.test/\"}","https://example.com/app.json","https://example.com/","Fallback");}catch(Error e){invalid=true;}assert(invalid);
        }catch(Error e){error("%s",e.message);}
    });
    Test.add_func("/storage/persistence-and-future-version",()=>{
        try{
            string directory=DirUtils.make_tmp("majoris-domain-XXXXXX");string path=Path.build_filename(directory,"browser.db");
            {
                var store=new Store(path);store.bookmark("https://example.com/","Persistent");store.save_session("one","saved",false);
            }
            {
                var store=new Store(path);assert(store.search(true)[0].title=="Persistent");assert(store.session("one")=="saved");assert(store.search(true,"' OR 1=1 --").size==0);
            }
            {
                Sqlite.Database db;assert(Sqlite.Database.open(path,out db)==Sqlite.OK);assert(db.exec("PRAGMA user_version=99")==Sqlite.OK);
            }
            bool rejected=false;try{new Store(path);}catch(Error e){rejected=true;}assert(rejected);
            FileUtils.remove(path);FileUtils.remove(path+"-wal");FileUtils.remove(path+"-shm");DirUtils.remove(directory);
        }catch(Error e){error("%s",e.message);}
    });
    Test.run ();
}
