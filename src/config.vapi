[CCode (cheader_filename = "config.h", cprefix = "")]
namespace Config {
    [CCode (cname = "VERSION")] public const string VERSION;
    [CCode (cname = "CEF_HELPER")] public const string CEF_HELPER;
    [CCode (cname = "CEF_RESOURCES")] public const string CEF_RESOURCES;
    [CCode (cname = "LOCALEDIR")] public const string LOCALEDIR;
}
