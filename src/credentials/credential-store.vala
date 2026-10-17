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
        public async void remove (string origin,string username) throws Error {
            yield Secret.password_clear(schema,null,"profile",profile,"origin",UrlResolver.origin(origin),"username",username,null);
        }
    }
}
