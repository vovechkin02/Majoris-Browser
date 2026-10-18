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
            assert (p.classify ("https://docs.google.com/document/d/abc/edit") == NavigationDecision.EXTERNAL);
            assert (p.classify ("https://docs.google.com/presentation/d/abc/edit") == NavigationDecision.EXTERNAL);
            var excel=new WebAppNavigationPolicy("https://www.microsoft365.com/launch/excel/");
            assert(excel.classify("https://www.microsoft365.com/launch/excel/workbook?x=1")==NavigationDecision.APP_SCOPE);
            assert(excel.classify("https://www.microsoft365.com/launch/word/")==NavigationDecision.EXTERNAL);
            assert(excel.classify("https://www.microsoft365.com/launch/outlook/")==NavigationDecision.EXTERNAL);
            assert(new WebAppNavigationPolicy("https://example.test/").classify("https://example.test/any/path")==NavigationDecision.APP_SCOPE);
            var custom=new WebApp("Custom","https://example.test/tools/editor/start","https://example.test/tools/editor/");
            assert(new WebAppNavigationPolicy(custom.scope).classify("https://example.test/tools/viewer/")==NavigationDecision.EXTERNAL);
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
            assert(policy.is_candidate("https://identity.example.test/authorize?redirect_uri=https%3A%2F%2Fdocs.google.com%2Fspreadsheets%2F&state=0123456789abcdef&client_id=fixture&response_type=code"));
            assert(!policy.is_candidate("https://identity.example.test/authorize?redirect_uri=https%3A%2F%2Fevil.test%2F&state=0123456789abcdef&client_id=fixture&response_type=code"));
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
    Test.add_func("/bookmarks/html-roundtrip",()=>{
        try{var rows=new Gee.ArrayList<Record>();rows.add(new Record(1,"https://example.com/?x=1&y=2","A < B","Work"));rows.add(new Record(2,"https://second.test/","Second",""));var parsed=BookmarkFormat.parse(BookmarkFormat.export_html(rows));assert(parsed.size==2);bool found=false;foreach(var row in parsed)if(row.title=="A < B"){assert(row.url==rows[0].url);assert(row.folder=="Work");found=true;}assert(found);assert(BookmarkFormat.parse("<DL><DT><A HREF='javascript:alert(1)'>Bad</A></DL>").size==0);}catch(Error e){error("%s",e.message);}
    });
    Test.add_func("/storage/v2-snapshots-permissions-folders-downloads",()=>{
        try{var store=new Store(":memory:");store.snapshot(20,"new",false);store.snapshot(10,"stale",true);assert(store.snapshot_state()=="new");assert(!store.snapshot_clean());store.snapshot(21,"clean",true);assert(store.snapshot_clean());
            store.permission("browser","https://example.com/path","camera",1);assert(store.permission_value("browser","https://example.com/","camera")==1);assert(store.permission_value("app","https://example.com/","camera")==0);store.permission("browser","https://example.com/","camera",2,1);assert(store.permission_value("browser","https://example.com/","camera")==0);store.reset_permissions("browser","https://example.com/");
            store.bookmark("https://example.com/","One","Work");store.rename_folder("Work","Projects");assert(store.search(true)[0].folder=="Projects");store.delete_folder("Projects");assert(store.search(true)[0].folder=="");store.save_download("uuid","metadata");assert(store.download_records()[0]=="metadata");store.remove_download("uuid");assert(store.download_records().size==0);store.never_save("browser","https://example.com",true);assert(store.password_blocked("browser","https://example.com"));assert(!store.password_blocked("app","https://example.com"));
        }catch(Error e){error("%s",e.message);}
    });
    Test.add_func("/webapps/install-publication-rollback",()=>{
        try{
            string root=DirUtils.make_tmp("majoris-install-XXXXXX");var store=new Store(":memory:");var app=new WebApp("Example","https://example.com/");WebAppInstaller.install(store,app,root);assert(store.get_app(app.id)!=null);assert(FileUtils.test(app.icon_path,FileTest.IS_REGULAR));assert(FileUtils.test(Path.build_filename(root,"applications",app.desktop_name),FileTest.IS_REGULAR));
            bool rejected=false;try{WebAppInstaller.install(store,app,root);}catch(Error e){rejected=true;}assert(rejected);assert(store.get_app(app.id)!=null);
            var failed=new WebApp("Rollback","https://rollback.test/");string blocked=DirUtils.make_tmp("majoris-install-blocked-XXXXXX");FileUtils.set_contents(Path.build_filename(blocked,"applications"),"file prevents launcher publication");rejected=false;try{WebAppInstaller.install(store,failed,blocked);}catch(Error e){rejected=true;}assert(rejected);assert(store.get_app(failed.id)==null);assert(!FileUtils.test(failed.icon_path,FileTest.EXISTS));
            // Test roots contain no user data. Remove only the files allocated here.
            FileUtils.remove(app.icon_path);FileUtils.remove(Path.build_filename(root,"applications",app.desktop_name));FileUtils.remove(Path.build_filename(blocked,"applications"));
        }catch(Error e){error("%s",e.message);}
    });
    Test.add_func("/import/read-only-profile-data",()=>{
        try{var store=new Store(":memory:");int count=ProfileImport.chromium_bookmarks(store,"{\"roots\":{\"bar\":{\"type\":\"folder\",\"name\":\"Work\",\"children\":[{\"type\":\"url\",\"name\":\"Example\",\"url\":\"https://example.com/\"},{\"type\":\"url\",\"name\":\"Unsafe\",\"url\":\"javascript:alert(1)\"}]}}}");assert(count==1);assert(store.search(true)[0].folder=="Work");
            string root=DirUtils.make_tmp("majoris-import-test-XXXXXX"),path=Path.build_filename(root,"History");{Sqlite.Database db;assert(Sqlite.Database.open(path,out db)==Sqlite.OK);assert(db.exec("CREATE TABLE urls(url TEXT,title TEXT,last_visit_time INTEGER); INSERT INTO urls VALUES('https://example.com/','Example',13300000000000000)")==Sqlite.OK);}string before;FileUtils.get_contents(path,out before);assert(ProfileImport.history(store,path,false)==1);string after;FileUtils.get_contents(path,out after);assert(before==after);assert(!FileUtils.test(path+"-shm",FileTest.EXISTS));assert(!FileUtils.test(path+"-wal",FileTest.EXISTS));FileUtils.set_contents(path+"-wal","busy");bool refused=false;try{ProfileImport.history(store,path,false);}catch(Error e){refused=true;}assert(refused);FileUtils.remove(path+"-wal");FileUtils.remove(path);DirUtils.remove(root);
            store.save_address("id","Home","{\"name\":\"Example\"}");assert(store.addresses()[0].title=="Home");store.save_address("id","Updated","{}");assert(store.addresses().size==1);store.delete_address("id");assert(store.addresses().size==0);
        }catch(Error e){error("%s",e.message);}
    });
    Test.add_func("/bookmarks/bar-order-and-rename",()=>{
        try{var store=new Store(":memory:");store.bookmark("https://one.test/","One");store.bookmark("https://two.test/","Two");store.create_folder("Empty");var items=store.bar_items();assert(items.size==3);string first=items[0].folder,second=items[1].folder;store.reorder_bar(second,first);assert(store.bar_items()[0].folder==second);store.reorder_bar("folder:Empty",second);assert(store.bar_items()[0].title=="Empty");store.rename_folder("Empty","Renamed");assert(store.bar_items()[0].title=="Renamed");store.rename_folder("Renamed","Renamed");assert(store.folders().contains("Renamed"));store.reorder_bar("untrusted","folder:Renamed");assert(store.bar_items().size==3);}catch(Error e){error("%s",e.message);}
    });
    Test.add_func("/lifecycle/exit-intent",()=>{
        var exit=new ExitOperation();assert(exit.begin(true));assert(!exit.begin(true));assert(!exit.approve(false));assert(!exit.finish(false));exit.cancel();assert(!exit.finish(true));assert(exit.begin(false));assert(exit.approve(true));assert(!exit.finish(true));assert(!exit.finish(true));
        var confirmed=new ExitOperation();assert(confirmed.begin(true));assert(confirmed.approve(true));assert(!confirmed.finish(false));assert(confirmed.finish(true));assert(!confirmed.finish(true));
    });
    Test.add_func("/tabs/audio-transitions",()=>{
        var state=new TabAudioState();assert(state.icon==null);state.update("audio","1");assert(state.icon=="audio-volume-high-symbolic");state.update("muted","1");state.update("audio","0");assert(state.icon=="audio-volume-muted-symbolic");state.update("muted","0");assert(state.icon==null && !state.available);state.update("audio","1");state.update("navigation-started","");assert(state.icon==null);state.update("muted","1");state.update("crashed","");assert(state.muted && !state.playing);
    });
    Test.add_func("/import/firefox-bookmarks",()=>{
        try{string root=DirUtils.make_tmp("majoris-firefox-import-XXXXXX"),path=Path.build_filename(root,"places.sqlite");{
            Sqlite.Database db;assert(Sqlite.Database.open(path,out db)==Sqlite.OK);assert(db.exec("CREATE TABLE moz_places(id INTEGER PRIMARY KEY,url TEXT,title TEXT);CREATE TABLE moz_bookmarks(id INTEGER PRIMARY KEY,type INTEGER,fk INTEGER,parent INTEGER,title TEXT);INSERT INTO moz_places VALUES(1,'https://example.test/','Fallback'),(2,'javascript:alert(1)','Unsafe');INSERT INTO moz_bookmarks VALUES(1,2,NULL,0,''),(2,2,NULL,1,'Toolbar'),(3,2,NULL,2,'Work'),(4,1,1,3,'Saved title'),(5,1,2,3,'Unsafe')")==Sqlite.OK);
        }uint8[] before,after;FileUtils.get_data(path,out before);var store=new Store(":memory:");assert(ProfileImport.firefox_bookmarks(store,path)==1);var rows=store.search(true);assert(rows.size==1 && rows[0].title=="Saved title" && rows[0].folder=="Toolbar / Work");FileUtils.get_data(path,out after);assert(before.length==after.length && Memory.cmp(before,after,before.length)==0);assert(!FileUtils.test(path+"-shm",FileTest.EXISTS));FileUtils.set_contents(path+"-wal","busy");bool refused=false;try{ProfileImport.firefox_bookmarks(store,path);}catch(Error e){refused=true;}assert(refused);FileUtils.remove(path+"-wal");FileUtils.remove(path);DirUtils.remove(root);
        }catch(Error e){error("%s",e.message);}
    });
    Test.add_func("/storage/category-and-time-clearing",()=>{
        try{var store=new Store(":memory:");int64 now=new DateTime.now_utc().to_unix();store.imported_visit("https://old.test/","Old",now-7200);store.imported_visit("https://recent.test/","Recent",now);store.bookmark("https://saved.test/","Saved");store.permission("browser","https://site.test/","camera",1);store.permission("app-id","https://site.test/","camera",1);store.never_save("browser","https://site.test/",true);store.save_address("home","Home","{}");
            store.save_download("recent","{\"profile\":\"browser\",\"status\":\"complete\",\"started\":"+now.to_string()+"}");store.save_download("old","{\"profile\":\"browser\",\"status\":\"complete\",\"started\":1}");store.save_download("active","{\"profile\":\"browser\",\"status\":\"active\",\"started\":"+now.to_string()+"}");store.save_download("app","{\"profile\":\"app-id\",\"status\":\"complete\",\"started\":"+now.to_string()+"}");
            store.clear_browser_records(true,true,true,now-3600,true);assert(store.search(false).size==1 && store.search(false)[0].title=="Old");assert(store.search(true).size==1);assert(store.permission_value("browser","https://site.test/","camera")==0);assert(store.permission_value("app-id","https://site.test/","camera")==1);assert(store.password_blocked("browser","https://site.test/"));assert(store.addresses().size==0 && store.download_records().size==3);
        }catch(Error e){error("%s",e.message);}
    });
    Test.add_func("/webapps/section-scope-and-legacy",()=>{
        try{var app=new WebApp("Section","https://example.test/app/document/edit?token=x#fragment");assert(app.scope=="https://example.test/app/" && app.scope_source=="inferred");var policy=new WebAppNavigationPolicy(app.scope);
            foreach(string url in new string[]{"https://example.test/application-other/","https://example.test/app/../outside/","https://example.test/app/%2e%2e/outside/","https://example.test/app%2foutside/","https://example.test:444/app/"})assert(policy.classify(url)==NavigationDecision.EXTERNAL);
            assert(policy.classify("https://example.test/app/child?q=1")==NavigationDecision.APP_SCOPE);var store=new Store(":memory:");store.put_app(app);string identity=app.id;app.scope_source="confirmed";store.put_app(app);assert(store.get_app(identity).scope==app.scope && store.get_app(identity).scope_source=="confirmed");
            var manifest=WebApp.from_manifest("{\"start_url\":\"/app/start\",\"scope\":\"/\"}","https://example.test/manifest.json","https://example.test/app/","Name");assert(manifest.scope=="https://example.test/" && manifest.scope_source=="manifest");
            var legacy=WebApp.deserialize("{\"id\":\"a0123456789abcdef0123456789abcdef\",\"name\":\"Legacy\",\"start_url\":\"https://example.test/app/start\",\"scope\":\"https://example.test/\",\"installed_at\":1}");assert(legacy.scope=="https://example.test/" && legacy.scope_source=="legacy");assert(WebApp.deserialize(legacy.serialize()).id==legacy.id);
        }catch(Error e){error("%s",e.message);}
    });
    Test.run ();
}
