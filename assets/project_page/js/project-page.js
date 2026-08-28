// Trimmed rewrite of the AI4CO research-project-page-template's
// static/js/index.js, itself a fork of the Academic Project Page Template's.
//
// Two deliberate differences from upstream: jQuery is dropped, and every DOM
// lookup is guarded, so a page that omits the BibTeX block or a code cell does
// nothing instead of throwing. Upstream's carousel and slider setup is also
// dropped -- neither library is loaded, because nothing here uses them.

// Copy-to-clipboard for every .code-container block. Markup contract comes from
// the AI4CO research-project-page-template; the clipboard handling is this
// page's own, because upstream uses only the deprecated execCommand path.
function initCopyButtons() {
  document.querySelectorAll(".code-container").forEach((container) => {
    const button = container.querySelector(".copy-button");
    const content = container.querySelector(".code-content");
    const tooltip = container.querySelector(".copy-tooltip");
    if (!button || !content) return;

    const flashCopied = () => {
      button.classList.add("copied");
      if (tooltip) tooltip.textContent = "Copied!";
      setTimeout(() => {
        button.classList.remove("copied");
        if (tooltip) tooltip.textContent = "Copy to clipboard";
      }, 2000);
    };

    const fallbackCopy = (text) => {
      const scratch = document.createElement("textarea");
      scratch.value = text;
      scratch.setAttribute("style", "position:fixed;top:0;left:0;opacity:0;pointer-events:none;");
      document.body.appendChild(scratch);
      scratch.select();
      const copied = document.execCommand("copy");
      document.body.removeChild(scratch);
      if (copied) flashCopied();
    };

    button.addEventListener("click", () => {
      const text = content.textContent.trim();
      const clipboard = navigator.clipboard;
      if (!clipboard || typeof clipboard.writeText !== "function") {
        fallbackCopy(text);
        return;
      }
      try {
        clipboard.writeText(text).then(flashCopied, () => fallbackCopy(text));
      } catch (err) {
        fallbackCopy(text);
      }
    });
  });
}

document.addEventListener("DOMContentLoaded", () => {
  if (typeof hljs !== "undefined") {
    hljs.highlightAll();
  }
  initCopyButtons();
});
