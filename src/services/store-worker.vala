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
        public StoreWorker (string path) {
            worker = new Thread<void*> ("browser-storage", () => {
                try {
                    var store = new Store (path);
                    while (true) { var job = queue.pop (); if (job.final_job) break; try { job.operation (store); } catch (Error e) { warning ("Browser persistence: %s",e.message); } }
                } catch (Error e) { warning ("Browser storage startup: %s",e.message); }
                return null;
            });
        }
        public void run (owned StoreOperation operation) { queue.push (new StoreJob ((owned)operation)); }
        public void stop () { var job = new StoreJob ((store) => {}); job.final_job = true; queue.push (job); worker.join (); }
    }
}
