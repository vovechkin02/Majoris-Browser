using MajorisBrowser;
class TestShell : Object, ShellIntegration {
    public bool pinned=true;
    public bool reject_unpin;
    public bool is_pinned(string id){return pinned;}
    public bool set_pinned(string id,bool value){if(!value && reject_unpin)return false;pinned=value;return true;}
}
int main(string[] args){
    try{
        string home=DirUtils.make_tmp("majoris-uninstall-test-XXXXXX");var paths=new ProfilePaths(home);paths.prepare();var store=new Store(paths.browser_store);var shell=new TestShell();
        FileUtils.set_contents(Path.build_filename(paths.browser_context,"keep"),"browser");
        var app=new WebApp("Fixture","https://one.example.test/");WebAppInstaller.install(store,app,home);string profile=paths.webapp_context(app.id);FileUtils.set_contents(Path.build_filename(profile,"keep"),"app");string desktop=Path.build_filename(home,"applications",app.desktop_name);
        int lease=MajorisCef.acquire_profile(profile);bool busy=false;try{WebAppManager.uninstall(store,app,home,true,shell);}catch(Error e){busy=true;}MajorisCef.release_profile(lease);assert(busy && store.get_app(app.id)!=null);
        shell.reject_unpin=true;bool failed=false;try{WebAppManager.uninstall(store,app,home,true,shell);}catch(Error e){failed=true;}assert(failed && shell.pinned);assert(store.get_app(app.id)!=null && !store.uninstall_pending(app.id));assert(FileUtils.test(desktop,FileTest.EXISTS) && FileUtils.test(app.icon_path,FileTest.EXISTS) && FileUtils.test(profile,FileTest.IS_DIR));
        shell.reject_unpin=false;WebAppManager.uninstall(store,app,home,false,shell);assert(!shell.pinned && store.get_app(app.id)==null && !store.uninstall_pending(app.id));assert(FileUtils.test(Path.build_filename(profile,"keep"),FileTest.EXISTS));assert(!FileUtils.test(desktop,FileTest.EXISTS));
        WebAppInstaller.install(store,app,home);
        File.new_for_path(desktop).move(File.new_for_path(desktop+".uninstalling"),FileCopyFlags.NONE);
        File.new_for_path(app.icon_path).move(File.new_for_path(app.icon_path+".uninstalling"),FileCopyFlags.NONE);
        store.begin_uninstall(app,true);
        // A real nonempty directory makes cleanup fail before data deletion.
        FileUtils.remove(app.icon_path+".uninstalling");DirUtils.create(app.icon_path+".uninstalling",0700);FileUtils.set_contents(app.icon_path+".uninstalling/block","retry");
        failed=false;try{WebAppManager.uninstall(store,app,home,false,shell);}catch(Error e){failed=true;}
        assert(failed && store.get_app(app.id)==null && store.uninstall_pending(app.id));assert(FileUtils.test(Path.build_filename(profile,"keep"),FileTest.EXISTS));
        {var reopened=new Store(paths.browser_store);assert(reopened.pending_uninstalls().size==1);assert(reopened.pending_uninstalls()[0].id==1);}
        bool reinstall_refused=false;try{WebAppInstaller.install(store,app,home);}catch(Error e){reinstall_refused=true;}assert(reinstall_refused);
        FileUtils.remove(app.icon_path+".uninstalling/block");DirUtils.remove(app.icon_path+".uninstalling");WebAppManager.uninstall(store,app,home,false,shell);assert(!store.uninstall_pending(app.id));assert(!FileUtils.test(profile,FileTest.EXISTS));assert(FileUtils.test(Path.build_filename(paths.browser_context,"keep"),FileTest.EXISTS));
        stdout.printf("Real SQLite/filesystem uninstall rollback, durable retry, lock exclusion, keep/delete choices and Browser preservation: PASS\n");
    }catch(Error e){error("%s",e.message);}return 0;
}
