#!/usr/bin/env bash
# Verifies the standalone academic project page renders as designed.
#
#   bin/verify-project-page.sh [url]
#
# Defaults to the local Jekyll dev server. Exits non-zero if any check fails.
#
# Conventions for patterns passed to check/refute:
#   * They are extended regular expressions (grep -E). Escape dots in asset
#     paths: 'bulma\.min\.css', not 'bulma.min.css', which also matches
#     'bulmaXmin.css'.
#   * The fetched page is flattened to one line before matching, so a pattern
#     may span what is several lines in the served HTML.
#   * Never call check/refute/fetch inside a pipeline, a $( ), or a background
#     job.
#     The failure counter lives in this shell; a subshell's copy is discarded
#     and the failure vanishes.
set -uo pipefail

URL="${1:-http://localhost:8080/projects/j_zero/}"
fails=0
haystack=''

fail() { # fail <description> <detail line>
  printf '  FAIL %s\n         %s\n' "$1" "$2"
  fails=$((fails + 1))
}

# grep exits 0 = matched, 1 = no match, >=2 = bad pattern or read error. The
# error case must never be mistaken for "absent" — a typo in a refute pattern
# would otherwise read as a passing isolation check.
# Both helpers refuse to run against a missing pattern or an unloaded page.
# Without those two guards an assertion can pass for the wrong reason: `set -u`
# on an absent $2 kills the pipeline subshell with status 1, which looks exactly
# like "pattern absent", and grep over an empty $haystack also exits 1. Either
# would turn an isolation refute into a silent pass.
guard() { # guard <description> <pattern>; non-zero means do not run the match
  if [ -z "${2-}" ]; then
    fail "$1" "called with no pattern"
    return 1
  fi
  if [ -z "$haystack" ]; then
    fail "$1" "no page loaded, cannot assert anything about it"
    return 1
  fi
  return 0
}

check() { # check <description> <grep-pattern>
  guard "$1" "${2-}" || return
  printf '%s' "$haystack" | grep -qE -- "$2"
  case $? in
    0) printf '  ok   %s\n' "$1" ;;
    1) fail "$1" "pattern not found: $2" ;;
    *) fail "$1" "grep error, bad pattern: $2" ;;
  esac
}

refute() { # refute <description> <grep-pattern>
  guard "$1" "${2-}" || return
  printf '%s' "$haystack" | grep -qE -- "$2"
  case $? in
    0) fail "$1" "unexpectedly matched: $2" ;;
    1) printf '  ok   %s\n' "$1" ;;
    *) fail "$1" "grep error, bad pattern: $2" ;;
  esac
}

# Fetch <url> into $haystack, flattened to one line, asserting HTTP 200.
# curl --fail only trips on >=400, so a URL missing its trailing slash would
# hand back a 301 stub and still be reported as a healthy page.
fetch() { # fetch <url> <label>
  local body code
  body="$(mktemp)"
  if ! code="$(curl -sS -o "$body" -w '%{http_code}' "$1")"; then
    rm -f "$body"
    haystack=''
    fail "$2" "curl could not reach $1"
    return 1
  fi
  if [ "$code" != "200" ]; then
    rm -f "$body"
    haystack=''
    fail "$2" "returned HTTP $code, expected 200"
    return 1
  fi
  haystack="$(tr '\n' ' ' < "$body")"
  rm -f "$body"
  if [ -z "$haystack" ]; then
    fail "$2" "returned an empty body"
    return 1
  fi
  printf '  ok   %s returns 200\n' "$2"
  return 0
}

printf 'Checking %s\n' "$URL"
fetch "$URL" 'project page' || exit 1

# --- Task 2: standalone Bulma document, no al-folio chrome ---
check  'loads vendored Bulma'        'assets/project_page/css/bulma\.min\.css'
check  'loads the template theme'    'assets/project_page/css/index\.css'
check  'loads academicons locally'   'assets/css/academicons\.min\.css'
check  'loads FontAwesome from CDN'  'cdn\.jsdelivr\.net/npm/@fortawesome/fontawesome-free@6\.5\.2'
check  'FontAwesome is SRI-pinned'   'integrity="sha256-XOqroi11tY4EFQMR9ZYwZWKj5ZXiftSx36RRuC3anlA="'
check  'title names the site owner'  '<title>[^<]*\|[^<]*Gyouk[[:space:]]+Chu[[:space:]]*</title>'
check  'carries a CSP'               'http-equiv="Content-Security-Policy" content="default-src'
check  'page script is cache-busted' 'project-page\.js\?v='
check  'emits a favicon'          'rel="shortcut icon"'
check  'loads the AI4CO fonts'      'fonts\.googleapis\.com/css\?family=Google\+Sans\|Noto\+Sans\|Castoro'
refute 'no al-folio Bootstrap'       'assets/css/bootstrap\.min\.css'
refute 'no al-folio theme script'    'assets/js/theme\.js'
refute 'no al-folio navbar'          'id="navbarNav"'
refute 'no al-folio stylesheet'      'assets/css/main\.css'

# --- Task blocks follow below in task order. A new task APPENDS its block at
#     the END of the list, immediately above the tally --- not directly below
#     this comment, which would reverse the order.

# --- Task 3: hero ---
# Structural: these hold for any paper page built on this layout.
check 'hero renders the title'        'class="title is-1 publication-title"'
# The affiliation span carries `author-block affiliation-block`, so a pattern that
# ends at the closing quote matches only real authors. Without that distinction,
# deleting every author left the suite green.
check 'hero renders an author'        '<span class="author-block">'
check 'hero renders the affiliations' '<span class="author-block affiliation-block">'
check 'hero renders the venue'        'class="publication-venue"'
check 'hero renders link buttons'     'class="external-link button is-normal is-rounded is-dark"'
# Page-data: these assert THIS page's front matter, not a contract the layout
# holds up. Point the script at a different paper page and expect these to fail.
check 'page data: author page link'   'https://gyoukchu\.github\.io'
check 'page data: author superscript' '</a><sup>1</sup>'
check 'page data: affiliation name'   '<sup>1</sup>KAIST'
# Not structural: a paper with no arXiv link is legitimate and would fail this.
check 'page data: arXiv link'         'class="ai ai-arxiv"'
# Asserted here rather than in the Task 5 block for the same reason -- it pins
# this page's citation key, not the bibtex include's behaviour.
check 'page data: citation key'       '@article\{chu2026jzero'
check 'page data: paper title'        'J-Zero: Unified Challenger–Solver–Judge Co-Evolution from Zero Data'
# This page now lists a single affiliation, so nothing here exercises the layout's
# multi-affiliation numbering any more; a second entry would render as <sup>2</sup>.
# The check that pinned the two-affiliation hero lived here until then.
refute 'no dropped affiliation'      '<sup>2</sup>'
# The Hugging Face button is a raw emoji, not an icon-font glyph; it proves the
# hero's emoji branch renders, not just that the link exists.
check 'page data: HF emoji button'    '<span class="icon">🤗</span>'
check 'page data: equal contribution' '<sup>\*</sup>equal contribution'

# --- Task 4: page scripts ---
check 'loads the page script'    'assets/project_page/js/project-page\.js'
refute 'no scroll-to-top button'  'class="scroll-to-top"'
# That only proves Task 2's HTML: emptying project-page.js left it green.
# Fetch the asset itself. No inline onclick handlers remain -- the copy buttons are
# wired by initCopyButtons() at DOMContentLoaded -- so the checks below assert the
# file's real contents instead, and an empty or truncated file fails them.
fetch "${URL%/projects/*}/assets/project_page/js/project-page.js" 'page script asset'
refute 'no scrollToTop function'  'scrollToTop'
# Asserted against the JS asset, not the page: the inline onclick is long gone,
# so a reintroduced copyBibTeX would carry no page-side trace to match on.
refute 'no legacy copyBibTeX call'  'copyBibTeX\('
check 'initCopyButtons is a global' 'function initCopyButtons'
# Restore the haystack so any later block still asserts against the page.
fetch "$URL" 'project page'

# --- Task 5: bibtex and footer ---
check 'bibtex section present'      'id="BibTeX"'
# Bounded at both ends, for the same reason the Task 8 code checks are: the
# haystack is one flattened line, so a leading 'id="BibTeX".*' alone only means
# "somewhere at or after the BibTeX section". That is sound today purely because
# BibTeX happens to be the last section on the page -- append any section with a
# .copy-button and this check silently goes vacuous. `<footer` is the layout's
# unconditional close after bibtex.liquid, so it is the boundary that cannot
# drift.
check 'bibtex copy button'          'id="BibTeX".*class="copy-button".*<footer'
refute 'no legacy bibtex button'    'copy-bibtex-btn'
# The entry now carries the real arXiv id, so `bibtex_placeholder` is gone from the
# front matter and the warning it rendered must be gone with it. Inverted from the
# check that guarded the notice while the citation was still fabricated.
refute 'no placeholder notice'      'id="BibTeX".*PLACEHOLDER.*<footer'
# The template is CC BY-SA 4.0 and the attribution is a licence obligation, so
# guard the licence text itself. Matching only the repo URL let the entire
# licence paragraph be deleted with the suite still green.
check 'footer credits the template' 'Academic-project-page-template'
check 'footer credits AI4CO'        'ai4co/research-project-page-template'
check 'footer states CC BY-SA 4.0'  'creativecommons\.org/licenses/by-sa/4\.0/'
check 'footer keeps the borrow note' 'link back to this page in the footer'
# Anchored to the nav container: bare href="/" would be satisfied by any
# root-relative link a later task adds elsewhere on the page.
check 'footer links back home'      'project-page-nav.*href="/"'
check 'footer links to /projects/'  'project-page-nav.*href="/projects/"'

# --- Task 6: mathjax ---
check 'loads MathJax 3.2.2'      'mathjax@3\.2\.2/es5/tex-mml-chtml\.js'
check 'configures MathJax'       'window\.MathJax'
check 'MathJax is SRI-pinned'    'integrity="sha256-MASABpB4tYktI2Oitl4t\+78w/lyA\+D7b/s9GEP0JOGI="'
# Those three only prove the head include. The extras stylesheet is linked by
# Task 2's check, which a 0-byte file also satisfies, so fetch the asset and
# assert the results contract actually has rules behind it.
fetch "${URL%/projects/*}/assets/project_page/css/project-page-extras.css" 'extras stylesheet asset'
check 'styles the results table'  '\.results-table'
# Every booktabs rule and the figure caption colour are var() references. Delete
# the :root block and they all resolve to nothing -- the rules render at 0px and
# the table silently degrades to a plain grid with the suite still green.
check 'extras defines the custom properties' '--text-primary: ?#363636'
check 'table wrapper scrolls'     '\.table-wrapper[[:space:]]*\{[^}]*overflow-x:[[:space:]]*auto'
check 'styles figure captions'    '\.project-figure figcaption'
# Restore the haystack so any later block still asserts against the page.
fetch "$URL" 'project page'

# --- Task 7: body sections (J-Zero paper content) ---
check 'teaser section'        'id="teaser"'
check 'abstract section'      'id="abstract"'
check 'abstract is light'     'section class="section hero is-light"'
check 'methodology section'   'id="methodology"'
check 'results section'       'id="results"'
check 'analysis section'      'id="analysis"'
check 'results table present' 'class="results-table"'
# Bare 'mathcal' survives kramdown mangling: \m is not an escape sequence, so the
# token passes through even when the delimiters are stripped and the subscripts
# are eaten into <em> pairs. Pin the delimiter and the subscript instead.
check 'math survived to HTML'  '\\\(\\mathcal\{D\}_\{\\mathrm\{role\}\}\\\)'
check 'figure present'        'class="project-figure"'
check 'figures have captions' '<figcaption'
# The three paper figures, rendered from the draft's PDFs.
check 'teaser image'          'assets/project_page/images/j_zero/teaser\.jpg'
check 'overview image'        'assets/project_page/images/j_zero/overview\.png'
check 'lifelong image'        'assets/project_page/images/j_zero/lifelong\.png'
# The teaser caption is the only italic one; is-italic is what carries that.
check 'teaser caption italic' 'figcaption class="is-italic"'
# The wrapper and the explicit <thead> are load-bearing: without them the table
# silently falls back to Bulma's grid. Cheap to pin, and exactly what a future
# editor deletes while tidying markup.
check 'table is wrapped'      'class="table-wrapper">[[:space:]]*<table class="results-table"'
check 'table has a thead'     'class="results-table">[[:space:]]*<thead>'
# The grouped header and block-label rows the main tables depend on.
check 'grouped header corner' '<th rowspan="2">Benchmark</th>'
check 'group label rows'      'class="group-label" colspan="9">Mathematical Reasoning'
check 'a best cell somewhere' '<td class="best">'
check 'section order'         'id="teaser".*id="abstract".*id="methodology".*id="results".*id="analysis".*id="BibTeX"'

# --- Task 8: code styling (the BibTeX copy block is its only consumer today) ---
# The Usage/code section was dropped with the real paper content -- the repo link
# in the hero covers it until the code release ships a snippet worth showing.
# highlight.js and code.css stay: bibtex.liquid renders through the same
# .code-container markup, and any future code cell picks them straight back up.
refute 'no leftover code section' 'id="code-example"'
check 'loads highlight.js theme' 'highlight\.js@11\.9\.0/styles/github\.min\.css'
check 'highlight.js is SRI-pinned' 'sha256-Oppd74ucMR5a5Dq96FxjEzGF7tTw2fZ/6ksAqDCM8GY='
check 'loads the code stylesheet' 'assets/project_page/css/code\.css'
# The link above is also satisfied by a 0-byte code.css, which costs the cell its
# container, its radius and the absolute positioning of the copy button. Fetch
# the asset and assert the two rules that carry the layout.
fetch "${URL%/projects/*}/assets/project_page/css/code.css" 'code stylesheet asset'
check 'styles the code container' '\.code-container[[:space:]]*\{[^}]*background-color'
check 'positions the copy button' '\.copy-button[[:space:]]*\{[^}]*position:[[:space:]]*absolute'
# Restore the haystack so any later block still asserts against the page.
fetch "$URL" 'project page'

# --- Task 9: AI4CO theme ---
# The button style lives in the stylesheet, not the page, so that one asserts
# against the theme asset and the haystack is restored after.
fetch "${URL%/projects/*}/assets/project_page/css/index.css" 'theme stylesheet'
check 'AI4CO flat dark button'   'background-color: ?#363636'
fetch "$URL" 'project page'
# Inter was imported by al-folio's head.liquid, never by the theme stylesheet, so
# refuting it against the stylesheet passed for the wrong reason -- it would have
# survived a full revert. Assert it against the page, which is where it would
# reappear.
refute 'no Inter font'           'family=Inter'
# 'affiliation-block.*publication-venue' also matched the old two-sibling markup,
# because the haystack is one flattened line. Pin the nesting: the venue span must
# close immediately inside its parent affiliation span.
check 'venue nests in the affiliations' 'publication-venue">[^<]*</span></span>'

# --- Task 12: the rest of the site still has its al-folio chrome ---
# Reuses fetch/check/refute, so these pages get the same HTTP 200 assertion and
# the same grep-error handling as the project page. fetch reloads $haystack, so
# every check below a fetch applies to that page.
printf '\nChecking the rest of the site is untouched\n'
origin="${URL%/projects/*}"
for path in / /projects/ /publications/; do
  fetch "${origin}${path}" "$path" || continue
  check  "$path keeps the dark mode toggle" 'assets/js/theme\.js'
  refute "$path has no Bulma"               'assets/project_page/css/bulma\.min\.css'
done

printf '\n'
if [ "$fails" -gt 0 ]; then
  printf '%d check(s) failed\n' "$fails"
  exit 1
fi
printf 'all checks passed\n'
