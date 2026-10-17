namespace MajorisBrowser {
    public class ManifestDiscovery : Object {
        public static string? find (string html,string document_url) throws Error {
            if(html.length>4*1024*1024)return null;
            var links=new Regex("<link\\b[^>]*>",RegexCompileFlags.CASELESS);
            var attrs=new Regex("(rel|href)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))",RegexCompileFlags.CASELESS);
            MatchInfo link;
            links.match(html,0,out link);
            while(link.matches()){
                string tag=link.fetch(0),rel="",href="";MatchInfo attr;attrs.match(tag,0,out attr);
                while(attr.matches()){
                    string value=attr.fetch(2);if(value=="")value=attr.fetch(3);if(value=="")value=attr.fetch(4);
                    if(attr.fetch(1).ascii_down()=="rel")rel=value;else href=value;
                    attr.next();
                }
                if(href!="")foreach(string token in Regex.split_simple("\\s+",rel))if(token.ascii_down()=="manifest"){
                    string resolved=Uri.resolve_relative(document_url,href.replace("&amp;","&"),UriFlags.NONE);
                    if(UrlResolver.origin(resolved)==UrlResolver.origin(document_url))return resolved;
                }
                link.next();
            }return null;
        }
    }
}
