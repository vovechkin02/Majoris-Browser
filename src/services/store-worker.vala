namespace MajorisBrowser {
    public delegate void StoreOperation (Store store) throws Error;
    public class StoreJob : Object {
        public StoreOperation operation;
        public bool final_job;
        public StoreJob (owned StoreOperation operation) { this.operation = (owned)operation; }
    }
    public class StoreWorker : Object {
        private AsyncQueue<StoreJob> queue = new AsyncQueue<StoreJob> ();
        private Thread<void*> worker;
        private Mutex startup_mutex;
        private Cond startup_condition;
        private bool ready;
        private bool stopped;
        private Error? startup_error;
        public signal void operation_failed(string message);
        public StoreWorker (string path) throws Error {
            worker = new Thread<void*> ("browser-storage", () => {
                try {
                    var store = new Store (path);
                    startup_mutex.lock();ready=true;startup_condition.signal();startup_mutex.unlock();
                    while (true) { var job = queue.pop (); if (job.final_job) break; try { job.operation (store); } catch (Error e) {string message=e.message;warning("Browser persistence: %s",message);Idle.add(()=>{operation_failed(message);return Source.REMOVE;});} }
                } catch (Error e) {startup_mutex.lock();startup_error=e;ready=true;startup_condition.signal();startup_mutex.unlock();}
                return null;
            });
            startup_mutex.lock();while(!ready)startup_condition.wait(startup_mutex);startup_mutex.unlock();
            if(startup_error!=null){worker.join();throw startup_error;}
        }
        public void run (owned StoreOperation operation) {if(!stopped)queue.push (new StoreJob ((owned)operation));}
        public void stop () {if(stopped)return;stopped=true;var job = new StoreJob ((store) => {}); job.final_job = true; queue.push (job); worker.join (); }
    }
}
