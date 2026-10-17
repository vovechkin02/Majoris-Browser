namespace MajorisBrowser {
    public class CredentialStore : Object {
        private Secret.Schema schema;
        private string profile;
        public CredentialStore (string profile) {
            this.profile=profile;
            schema=new Secret.Schema("com.majoris.browser.Credential",Secret.SchemaFlags.NONE,
                "profile",Secret.SchemaAttributeType.STRING,"origin",Secret.SchemaAttributeType.STRING,"username",Secret.SchemaAttributeType.STRING,null);
        }
        public async void save (string origin,string username,string password) throws Error {
            origin=UrlResolver.origin(origin);
            if(!origin.has_prefix("https://"))throw new BrowserError.INVALID_URL("Credentials require an HTTPS origin");
            if(!yield Secret.password_store(schema,Secret.COLLECTION_DEFAULT,"Majoris Browser · "+origin,password,null,"profile",profile,"origin",origin,"username",username,null))
                throw new BrowserError.STORAGE("Secret Service did not save the credential");
        }
        public async string? lookup (string origin,string username) throws Error {
            return yield Secret.password_lookup(schema,null,"profile",profile,"origin",UrlResolver.origin(origin),"username",username,null);
        }
        public async Gee.ArrayList<string> usernames(string origin) throws Error {
            var attributes=new HashTable<string,string>(str_hash,str_equal);attributes.insert("profile",profile);attributes.insert("origin",UrlResolver.origin(origin));
            var items=yield Secret.password_searchv(schema,attributes,Secret.SearchFlags.ALL,null);
            var result=new Gee.ArrayList<string>();foreach(var item in items){string? username=item.get_attributes().lookup("username");if(username!=null && !result.contains(username))result.add(username);}return result;
        }
        public async Gee.ArrayList<Record> entries() throws Error {
            var attributes=new HashTable<string,string>(str_hash,str_equal);attributes.insert("profile",profile);
            var items=yield Secret.password_searchv(schema,attributes,Secret.SearchFlags.ALL,null);var result=new Gee.ArrayList<Record>();
            foreach(var item in items){var attrs=item.get_attributes();string? origin=attrs.lookup("origin"),username=attrs.lookup("username");if(origin!=null && username!=null)result.add(new Record(0,origin,username));}return result;
        }
        public async void remove (string origin,string username) throws Error {
            yield Secret.password_clear(schema,null,"profile",profile,"origin",UrlResolver.origin(origin),"username",username,null);
        }
    }
}
