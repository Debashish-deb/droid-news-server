class WebViewTextExtractor {
  static const String jsExtractor = r"""
(function() {
  function clean(node) {
    const tagsToRemove = [
      'script', 'style', 'nav', 'footer', 'aside', 'noscript', 
      'header', '.ads', '.advertisement', '.social-share'
    ];
    tagsToRemove.forEach(tag => {
      node.querySelectorAll(tag).forEach(el => el.remove());
    });
  }

  // Try to find the main content
  let article = document.querySelector('article')
    || document.querySelector('[role="main"]')
    || document.querySelector('main')
    || document.querySelector('.post-content')
    || document.querySelector('.article-content')
    || document.body;

  // Clone to avoid mutating original page
  let clone = article.cloneNode(true);
  clean(clone);
  
  return clone.innerText || clone.textContent;
})();
""";

  Future<String> extract(dynamic webViewController) async {
    try {
      // Assuming InAppWebViewController or similar that supports evaluateJavascript
      final result = await webViewController.evaluateJavascript(source: jsExtractor);
      if (result == null) return '';
      
      // Basic sanitization
      return result
          .toString()
          .replaceAll(RegExp(r'\\n{2,}'), '\n')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();
    } catch (e) {
      return '';
    }
  }
}
