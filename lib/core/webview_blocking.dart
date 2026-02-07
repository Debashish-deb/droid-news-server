/// Shared constants for WebView content blocking rules.
///
/// Regex pattern used to block common ad/tracker URLs in in-app WebViews.
const String kAdUrlFilterPattern =
    r'.*(ads|doubleclick|googlesyndication|adservice|googleadservices|taboola|outbrain|adsystem|rubiconproject|openx).*';
