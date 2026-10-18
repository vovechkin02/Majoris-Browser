using MajorisBrowser;
async void verify(MainLoop loop,string root,bool real=false){
    try{
        var scanner=new ClamdDownloadScanner(root+"/clamd.sock");
        if(real){assert((yield scanner.assess(root+"/clean",new Cancellable())).verdict==DownloadAssessment.NO_KNOWN_THREAT);assert((yield scanner.assess(root+"/detected",new Cancellable())).verdict==DownloadAssessment.MALICIOUS);assert(FileUtils.test(root+"/detected",FileTest.IS_REGULAR));stdout.printf("Real disposable clamd: clean and harmless test-signature detection via production INSTREAM adapter; detected file retained: PASS\n");loop.quit();return;}
        assert((yield new NoDownloadScanner().assess(root+"/clean",new Cancellable())).verdict==DownloadAssessment.NOT_ASSESSED);
        assert((yield new ClamdDownloadScanner(root+"/absent.sock").assess(root+"/clean",new Cancellable())).verdict==DownloadAssessment.UNAVAILABLE);
        assert((yield scanner.assess(root+"/clean",new Cancellable())).verdict==DownloadAssessment.NO_KNOWN_THREAT);
        assert((yield scanner.assess(root+"/detected",new Cancellable())).verdict==DownloadAssessment.MALICIOUS);
        assert((yield scanner.assess(root+"/failed",new Cancellable())).verdict==DownloadAssessment.SCAN_FAILED);
        assert((yield scanner.assess(root+"/chunked",new Cancellable())).verdict==DownloadAssessment.NO_KNOWN_THREAT);
        assert((yield scanner.assess(root+"/replace",new Cancellable())).verdict==DownloadAssessment.SCAN_FAILED);
        foreach(string name in new string[]{"link","fifo","large"})assert((yield scanner.assess(root+"/"+name,new Cancellable())).verdict==DownloadAssessment.SCAN_FAILED);
        var cancel=new Cancellable();Timeout.add(50,()=>{cancel.cancel();return Source.REMOVE;});bool stopped=false;
        try{yield scanner.assess(root+"/slow",cancel);}catch(IOError.CANCELLED e){stopped=true;}assert(stopped);
        var timeout=new ClamdDownloadScanner.fixture(root+"/clamd.sock",50);stopped=false;try{yield timeout.assess(root+"/slow",new Cancellable());}catch(IOError.CANCELLED e){stopped=true;}assert(stopped);
        assert((yield scanner.assess(root+"/clean",new Cancellable())).verdict==DownloadAssessment.NO_KNOWN_THREAT);
        assert(FileUtils.test(root+"/detected",FileTest.IS_REGULAR));
        assert(ClamdDownloadScanner.database_info("ClamAV test/1/Sun Oct 18 10:00:00 2020 COMMANDS: INSTREAM").contains("Reported signature age:"));
        assert(ClamdDownloadScanner.database_info("ClamAV test/1/Sun Oct 18 10:00:00 2020| COMMANDS: INSTREAM").contains("Reported signature age:"));
        stdout.printf("Optional clamd INSTREAM: clean/detected/error/unavailable, bounds, symlink/FIFO refusal, cancellation/recovery and no deletion: PASS\n");loop.quit();
    }catch(Error e){error("Scanner fixture failed: %s",e.message);}
}
int main(string[] args){var loop=new MainLoop();verify.begin(loop,args[1],args.length>2 && args[2]=="--real");loop.run();return 0;}
