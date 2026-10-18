import Foundation

/// iOS 阅读进度桥：观察实际页面布局，不改动双端共享的渲染资源。
enum ReadingProgress {
    static let script = #"""
    (() => {
      const content = document.getElementById('content');
      if (!content) return;
      let pending = false;
      let last;
      function check() {
        pending = false;
        if (document.documentElement.classList.contains('ios-pdf-export') ||
            !content.innerHTML.trim() ||
            Array.from(content.querySelectorAll('img')).some(img => !img.complete)) return;
        const height = Math.max(document.documentElement.scrollHeight, document.body.scrollHeight);
        const atEnd = window.scrollY + window.innerHeight >= height - 8;
        if (last !== atEnd) {
          last = atEnd;
          window.webkit.messageHandlers.readingEnd.postMessage(atEnd);
        }
      }
      function schedule() {
        if (pending) return;
        pending = true;
        requestAnimationFrame(() => requestAnimationFrame(check));
      }
      window.addEventListener('scroll', schedule, { passive: true });
      window.addEventListener('resize', schedule);
      content.addEventListener('load', schedule, true);
      content.addEventListener('error', schedule, true);
      new ResizeObserver(schedule).observe(content);
      new MutationObserver(schedule).observe(document.documentElement, { attributes: true, attributeFilter: ['class'] });
      schedule();
    })();
    """#
}
