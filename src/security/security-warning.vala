namespace MajorisBrowser {
    public class SecurityWarning : Object {
        public static void present(Gtk.Widget owner,string url,ThreatResult result){
            string host="";try{host=UrlResolver.web_uri(url).get_host();}catch(Error e){}
            string category=result.verdict==ThreatVerdict.PHISHING?_("Phishing"):result.verdict==ThreatVerdict.MALWARE?_("Malware"):_("Unwanted software");
            var dialog=new Adw.AlertDialog(_("Dangerous Destination Blocked"),host+"\n"+category);
            dialog.add_response("back",_("Go Back"));dialog.add_response("details",_("Details"));dialog.close_response="back";dialog.default_response="back";
            dialog.response.connect((response)=>{if(response=="details"){var details=new Adw.AlertDialog(category,_("The configured reputation provider identified a known threat. The navigation was cancelled before loading the destination. No permanent exception has been granted."));details.add_response("back",_("Go Back"));details.present(owner);}});dialog.present(owner);
        }
    }
}
