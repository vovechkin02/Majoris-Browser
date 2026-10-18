namespace MajorisBrowser {
    public class FileAssessment : Object {
        public DownloadAssessment verdict;
        public string detail;
        public FileAssessment(DownloadAssessment verdict,string detail=""){this.verdict=verdict;this.detail=detail;}
    }
    public abstract class DownloadSecurityProvider : Object {
        public abstract bool configured {get;}
        public abstract async FileAssessment assess(string path,Cancellable cancel) throws Error;
    }
    public class NoDownloadScanner : DownloadSecurityProvider {
        public override bool configured {get{return false;}}
        public override async FileAssessment assess(string path,Cancellable cancel) throws Error {return new FileAssessment(DownloadAssessment.NOT_ASSESSED,"No scanner configured");}
    }
    // Only local clamd sockets. No subprocess, remote upload or daemon startup.
    public class ClamdDownloadScanner : DownloadSecurityProvider {
        private string socket_path;
        private bool busy;
        private uint deadline_ms=30000;
        private const int64 MAX_BYTES=64*1024*1024;
        public override bool configured {get{return true;}}
        public ClamdDownloadScanner(string socket_path){this.socket_path=socket_path;}
        internal ClamdDownloadScanner.fixture(string socket_path,uint deadline_ms){this(socket_path);this.deadline_ms=deadline_ms;}
        public override async FileAssessment assess(string path,Cancellable cancel) throws Error {
            if(busy)return new FileAssessment(DownloadAssessment.UNAVAILABLE,"Scanner busy; retry scanning");
            busy=true;FileAssessment result=new FileAssessment(DownloadAssessment.SCAN_FAILED,"Scan failed");
            uint deadline=0;deadline=Timeout.add(deadline_ms,()=>{deadline=0;cancel.cancel();return Source.REMOVE;});
            SourceFunc resume=assess.callback;
            new Thread<void*>("download-scan",()=>{
                try{result=scan(path,cancel);}catch(Error e){bool stopped=(e is IOError.CANCELLED);bool unavailable=(e is IOError.CONNECTION_REFUSED) || (e is IOError.NOT_FOUND) || (e is IOError.NOT_SUPPORTED);result=new FileAssessment(unavailable?DownloadAssessment.UNAVAILABLE:DownloadAssessment.SCAN_FAILED,stopped?"Scan cancelled":unavailable?"Scanner unavailable":"Scan failed");}
                Idle.add((owned)resume);return null;
            });
            yield;if(deadline!=0)Source.remove(deadline);busy=false;cancel.set_error_if_cancelled();return result;
        }
        private SocketConnection connect(Cancellable cancel) throws Error {
            if(!Path.is_absolute(socket_path) || socket_path.length>100)throw new IOError.INVALID_ARGUMENT("Invalid scanner socket");
            var client=new SocketClient();client.timeout=30;
            return client.connect(new UnixSocketAddress(socket_path),cancel);
        }
        private static void send(OutputStream output,uint8[] data,Cancellable cancel) throws Error {size_t written;output.write_all(data,out written,cancel);}
        private static void command(OutputStream output,string value,Cancellable cancel) throws Error {send(output,value.data,cancel);send(output,{0},cancel);}
        private static string reply(InputStream input,Cancellable cancel) throws Error {
            var bytes=new ByteArray();uint8[] one=new uint8[1];
            while(bytes.len<4096){if(input.read(one,cancel)!=1)throw new IOError.INVALID_DATA("Truncated scanner reply");if(one[0]==0){bytes.append({0});return (string)bytes.data;}bytes.append(one);}
            throw new IOError.INVALID_DATA("Oversize scanner reply");
        }
        private string version(Cancellable cancel) throws Error {
            var connection=connect(cancel);
            try{command(connection.output_stream,"zVERSIONCOMMANDS",cancel);var value=reply(connection.input_stream,cancel);if(!value.has_prefix("ClamAV ") || !value.contains("INSTREAM"))throw new IOError.NOT_SUPPORTED("Scanner protocol unsupported");return value;}finally{try{connection.close(null);}catch(Error e){}}
        }
        private FileAssessment scan(string path,Cancellable cancel) throws Error {
            cancel.set_error_if_cancelled();string database=version(cancel);
            // VERSION's date is daemon-reported, not proof of current signatures.
            string freshness=database_info(database);
            int fd=Posix.open(path,Posix.O_RDONLY|Posix.O_NOFOLLOW|Posix.O_NONBLOCK|Posix.O_CLOEXEC);
            if(fd<0)return new FileAssessment(DownloadAssessment.SCAN_FAILED,"File could not be opened safely");
            var input=new UnixInputStream(fd,true);Posix.Stat before;
            if(Posix.fstat(fd,out before)!=0 || !Posix.S_ISREG(before.st_mode) || before.st_size>MAX_BYTES){input.close(null);return new FileAssessment(DownloadAssessment.SCAN_FAILED,"Only regular files up to 64 MiB can be scanned");}
            SocketConnection? connection=null;
            try{
                connection=connect(cancel);command(connection.output_stream,"zINSTREAM",cancel);
                uint8[] buffer=new uint8[65536];int64 total=0;
                while(true){ssize_t count=input.read(buffer,cancel);if(count==0)break;total+=count;if(total>MAX_BYTES)throw new IOError.NO_SPACE("Scan limit exceeded");uint32 length=(uint32)count;uint8[] header={(uint8)(length>>24),(uint8)(length>>16),(uint8)(length>>8),(uint8)length};send(connection.output_stream,header,cancel);send(connection.output_stream,buffer[0:count],cancel);}
                send(connection.output_stream,{0,0,0,0},cancel);string answer=reply(connection.input_stream,cancel);Posix.Stat after=Posix.Stat(),current=Posix.Stat();
                if(Posix.fstat(fd,out after)!=0 || Posix.lstat(path,out current)!=0 || current.st_dev!=before.st_dev || current.st_ino!=before.st_ino || !Posix.S_ISREG(current.st_mode) || before.st_size!=after.st_size || before.st_mtim.tv_sec!=after.st_mtim.tv_sec || before.st_mtim.tv_nsec!=after.st_mtim.tv_nsec || before.st_ctim.tv_sec!=after.st_ctim.tv_sec || before.st_ctim.tv_nsec!=after.st_ctim.tv_nsec || total!=before.st_size)return new FileAssessment(DownloadAssessment.SCAN_FAILED,"File changed during scanning");
                if(answer=="stream: OK")return new FileAssessment(DownloadAssessment.NO_KNOWN_THREAT,"No threat detected; this is not a guarantee of safety. "+freshness);
                if(answer.has_prefix("stream: ") && answer.has_suffix(" FOUND"))return new FileAssessment(DownloadAssessment.MALICIOUS,"Known threat detected by local scanner. "+freshness);
                return new FileAssessment(DownloadAssessment.SCAN_FAILED,"Scanner did not complete assessment. "+freshness);
            }finally{try{input.close(null);}catch(Error e){}try{if(connection!=null)connection.close(null);}catch(Error e){}}
        }
        internal static string database_info(string version){
            string reported=version.split(" COMMANDS:",2)[0],age="Signature freshness unknown";
            reported=reported.strip();if(reported.has_suffix("|"))reported=reported.substring(0,reported.length-1).strip();
            string[] pieces=reported.split("/",3);
            if(pieces.length==3)try{
                var pattern=new Regex("^[A-Za-z]{3} ([A-Za-z]{3}) +([0-9]+) ([0-9]+):([0-9]+):([0-9]+) ([0-9]{4})$");MatchInfo match;
                if(pattern.match(pieces[2],0,out match)){
                    string[] months={"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"};int month=0;for(int i=0;i<12;i++)if(months[i]==match.fetch(1))month=i+1;
                    if(month>0){var date=new DateTime.local(int.parse(match.fetch(6)),month,int.parse(match.fetch(2)),int.parse(match.fetch(3)),int.parse(match.fetch(4)),int.parse(match.fetch(5)));if(date!=null){int64 days=new DateTime.now_local().difference(date)/TimeSpan.DAY;if(days>=0)age="Reported signature age: "+days.to_string()+" days";}}
                }
            }catch(Error e){}
            return reported+". "+age+"; current official signatures are the operator's responsibility.";
        }
    }
}
