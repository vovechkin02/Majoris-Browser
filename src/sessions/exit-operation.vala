namespace MajorisBrowser {
    public enum ExitPhase { IDLE, PENDING, CANCELLED, APPROVED, COMPLETE }
    // One explicit exit transaction. A later ordinary shutdown cannot inherit
    // a destructive intent from a cancelled transaction.
    public class ExitOperation : Object {
        public ExitPhase phase { get; private set; default=ExitPhase.IDLE; }
        private bool clear_requested;
        public uint64 generation { get; private set; }
        public bool begin(bool clear){
            if(phase==ExitPhase.PENDING || phase==ExitPhase.APPROVED || phase==ExitPhase.COMPLETE)return false;
            generation++;clear_requested=clear;phase=ExitPhase.PENDING;return true;
        }
        public void cancel(){
            if(phase==ExitPhase.COMPLETE)return;
            clear_requested=false;phase=ExitPhase.CANCELLED;
        }
        public bool approve(bool all_windows_closed){
            if(phase!=ExitPhase.PENDING || !all_windows_closed)return false;
            phase=ExitPhase.APPROVED;return true;
        }
        public bool finish(bool engine_stopped){
            if(phase!=ExitPhase.APPROVED || !engine_stopped)return false;
            bool clear=clear_requested;clear_requested=false;phase=ExitPhase.COMPLETE;return clear;
        }
    }
}
