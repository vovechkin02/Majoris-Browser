namespace MajorisBrowser {
    public class ProfileCleaner : Object {
        public static async void clear (string path) throws Error {
            Error? failure=null;
            SourceFunc resume=clear.callback;
            new Thread<void*>("profile-cleaner",()=>{
                try{MajorisCef.clear_profile(path);}catch(Error e){failure=e;}
                Idle.add((owned)resume);return null;
            });
            yield;
            if(failure!=null)throw failure;
        }
    }
}
