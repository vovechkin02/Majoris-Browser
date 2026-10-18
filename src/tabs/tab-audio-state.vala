namespace MajorisBrowser {
    public class TabAudioState : Object {
        public bool playing;
        public bool muted;
        public string? icon { owned get {return muted?"audio-volume-muted-symbolic":playing?"audio-volume-high-symbolic":null;} }
        public bool available { get {return playing || muted;} }
        public void update(string kind,string value){
            if(kind=="audio")playing=value=="1";
            if(kind=="muted")muted=value=="1";
            if(kind=="crashed" || kind=="closed" || kind=="navigation-started")playing=false;
        }
    }
}
