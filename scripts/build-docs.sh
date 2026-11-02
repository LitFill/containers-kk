#!/usr/bin/env bash
#
# Generate the HTML API reference for a Koka library.
#
# The Koka compiler's `--html` backend writes one page per module into a
# build directory: `<module>.xmp.html` (signatures, doc comments, inline
# table of contents) and `<module>-source.html` (annotated source). It emits no
# site scaffolding, though — every page links to `toc.html` and
# `styles/koka.css`, and neither is written. This script finds every module
# under the source directory, runs the compiler on each, collects the output,
# and supplies the missing pieces (stylesheet, contents page, index page).
#
# Usage: scripts/build-docs.sh <out-dir>
#
# Environment (all optional):
#   KOKA                  koka binary             (default: koka on PATH)
#   KOKA_FLAGS            extra compiler flags, split on whitespace — the
#                         flake passes the dependency `--include=...` flags
#                         here                    (default: none)
#   KOKA_DOC_BASE         base URL for standard library links
#                         (default: https://koka-lang.github.io/koka/doc/)
#   SOURCE_DIR            directory, relative to the repo root, searched
#                         recursively for `*.kk`  (default: src)
#   KOKA_DOC_SKIP         whitespace-separated globs, relative to the repo
#                         root, of sources to leave out, e.g. "src/internal/*"
#   PROJECT_NAME          name shown in titles    (default: repo dir name)
#   PROJECT_DESCRIPTION   one-line summary for the index page (plain text)
#   DOCS_INTRO_FILE       HTML fragment inserted on the index page, relative
#                         to the repo root: usage examples and the like
#                         (default: docs-intro.html, used only if it exists)
#
# <out-dir> is deleted and recreated on every run, so the script refuses an
# out-dir that contains any `.kk` file (the repo root, the source dir, `/`).
#
# Modules importing each other by path (`import sub/mod` from a file that is
# not next to it) need `--include=<dir>` in KOKA_FLAGS, as with plain koka.

set -euo pipefail

readonly KOKA="${KOKA:-koka}"
readonly KOKA_DOC_BASE="${KOKA_DOC_BASE:-https://koka-lang.github.io/koka/doc/}"
readonly KOKA_DOC_SKIP="${KOKA_DOC_SKIP:-}"

SOURCE_DIR="${SOURCE_DIR:-src}"
SOURCE_DIR="${SOURCE_DIR%/}"
readonly SOURCE_DIR

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  echo "usage: $0 <out-dir>" >&2
  exit 64
fi

readonly OUT_DIR="$1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly ROOT_DIR
readonly SRC_ROOT="$ROOT_DIR/$SOURCE_DIR"
readonly BUILD_DIR="$ROOT_DIR/.koka/docs"

PROJECT_NAME="${PROJECT_NAME:-$(basename "$ROOT_DIR")}"
readonly PROJECT_NAME
readonly PROJECT_DESCRIPTION="${PROJECT_DESCRIPTION:-API reference for $PROJECT_NAME, a Koka library.}"
readonly DOCS_INTRO_FILE="${DOCS_INTRO_FILE:-docs-intro.html}"

# Filled by discover_modules: repo-relative paths such as src/foo/bar.kk.
MODULES=()

die() {
  echo "error: $*" >&2
  exit 1
}

# ---- small portable helpers --------------------------------------------------
# GNU-only `sed -i`, `sed 0,/re/` and `find -printf` are avoided on purpose:
# the flake also targets macOS, where the BSD versions reject them.

# awk_inplace <file> <awk-args...> — run awk over <file> and replace it.
awk_inplace() {
  local file="$1" tmp
  shift
  tmp="$(mktemp)"
  awk "$@" "$file" >"$tmp" || {
    rm -f "$tmp"
    return 1
  }
  cat "$tmp" >"$file"
  rm -f "$tmp"
}

# replace_literal <file> <old> <new> — replace every occurrence of <old>
# with <new>, treating both as plain text. Anchors such as `(|>)` or `(!^)`
# are full of characters that mean something to sed, and `|` is sed's own
# delimiter here; going through ENVIRON avoids every escaping rule.
replace_literal() {
  # shellcheck disable=SC2016  # `$0` is awk's, not the shell's
  OLD="$2" NEW="$3" awk_inplace "$1" '
    BEGIN { old = ENVIRON["OLD"]; new = ENVIRON["NEW"]; n = length(old) }
    {
      line = $0; out = ""
      while (n > 0 && (i = index(line, old)) > 0) {
        out = out substr(line, 1, i - 1) new
        line = substr(line, i + n)
      }
      print out line
    }'
}

# has_id <file> <anchor> — does <file> define id="<anchor>"? (fixed string)
has_id() { grep -qF "id=\"$2\"" "$1"; }

ids_of() { grep -o 'id="[^"]*"' "$1" | sed 's/^id="//; s/"$//' | sort -u || true; }

html_escape() { printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'; }

# ---- module discovery ---------------------------------------------------------

# page_slug src/a/b.kk -> src_a_b : with `-l`, koka names its pages after the
# source path with `/` turned into `_` (src/util.kk -> src_util.xmp.html).
page_slug() {
  local p="${1%.kk}"
  printf '%s' "${p//\//_}"
}

# module_name src/a/b.kk -> a/b : the name a user imports.
module_name() {
  local n="${1#"$SOURCE_DIR"/}"
  printf '%s' "${n%.kk}"
}

is_skipped() {
  local file="$1" pat
  local -a pats=()
  read -r -a pats <<<"$KOKA_DOC_SKIP"
  for pat in ${pats[@]+"${pats[@]}"}; do
    # shellcheck disable=SC2254  # the glob is meant to be a pattern
    case "$file" in $pat) return 0 ;; esac
  done
  return 1
}

discover_modules() {
  case "$SOURCE_DIR" in
  "" | /* | .. | ../* | */.. | */../*)
    die "SOURCE_DIR must be a relative path inside the repo: '$SOURCE_DIR'"
    ;;
  esac
  [ -d "$SRC_ROOT" ] || die "source directory not found: $SRC_ROOT"

  local file slugs
  while IFS= read -r file; do
    file="${file#"$ROOT_DIR"/}"
    if is_skipped "$file"; then continue; fi
    MODULES+=("$file")
  done < <(find "$SRC_ROOT" -type f -name '*.kk' | LC_ALL=C sort)

  [ "${#MODULES[@]}" -gt 0 ] || die "no .kk files under $SOURCE_DIR (after KOKA_DOC_SKIP)"

  # `a_b.kk` and `a/b.kk` would collide on one page name.
  slugs="$(for file in "${MODULES[@]}"; do
    page_slug "$file"
    echo
  done | sort | uniq -d)"
  [ -z "$slugs" ] || die "modules would share a page name: $slugs"
}

# Locate a page in the compiler output. Koka nests it as
# <builddir>/<koka-version>/<target-flags>/, and that depth is an internal
# detail that has changed between releases, so discover it rather than guess.
find_generated() {
  local found
  found="$(find "$BUILD_DIR" -type f -name "$1" 2>/dev/null | head -n 1)"
  [ -n "$found" ] || die "koka produced no $1 under $BUILD_DIR — did koka --html run?"
  printf '%s' "$found"
}

# ---- per-module post-processing ----------------------------------------------

# The two pages for a module — the API view and the annotated source — are
# generated separately and do not agree on every anchor. A struct's generated
# field projections (`util/head`) exist only in the API view, because a
# field has no line of its own in the source view; `-l` likewise drops the page
# that carried the module anchor. Where a cross-page link points at an anchor
# that is not on the page it names, retarget it to the page that has it.
# retarget_anchors <dir> <api-page> <source-page>
retarget_anchors() {
  local dir="$1" api="$2" source="$3"
  local page self_page other_page anchor
  for self_page in "$api" "$source"; do
    page="$dir/$self_page"
    if [ "$self_page" = "$api" ]; then other_page="$source"; else other_page="$api"; fi
    while IFS= read -r anchor; do
      [ -n "$anchor" ] || continue
      # Only worth retargeting if the anchor is here and missing over there.
      has_id "$page" "$anchor" || continue
      ! has_id "$dir/$other_page" "$anchor" || continue
      grep -qF "href=\"$other_page#$anchor\"" "$page" || continue
      replace_literal "$page" "href=\"$other_page#$anchor\"" "href=\"$self_page#$anchor\""
    done < <(ids_of "$page")
  done
}

# Koka links a module's name to `#_null_`, the anchor it places on a module
# page's heading. That heading carries no id, so give it the one the links
# expect (first <h1> only).
add_module_anchor() {
  local api_page="$1"
  awk_inplace "$api_page" '!done { if (sub(/<h1>/, "<h1 id=\"_null_\">")) done = 1 } { print }'
  has_id "$api_page" "_null_" || die "could not place the module anchor on $(basename "$api_page")"
}

# Koka wraps each doc comment in `<xmp>`, a long-deprecated HTML element whose
# content is raw text: the browser never parses it. The compiler nevertheless
# puts real markup inside — the doc comment for a generated struct projection
# carries a `<code class="koka">` and a linked type — so that markup escapes
# as literal `<code class="koka">head</code>` on the page. Hand-written
# comments are plain prose with no markup inside, which is why only the
# compiler's own comments show it.
#
# The enclosing `<div class="doc koka comment">` is an ordinary element, so
# dropping the `<xmp>` wrapper is enough to let the markup render.
# Returns 1 when the page had no `<xmp>` (a module without doc comments).
unwrap_raw_text_docs() {
  local api_page="$1"
  grep -qF '<xmp>' "$api_page" || return 1
  replace_literal "$api_page" '<xmp>' ''
  replace_literal "$api_page" '</xmp>' ''
  # `if`, not `grep && die`: the success case is grep exiting non-zero, which
  # would return that status from the function and trip `set -e`.
  if grep -qE '</?xmp>' "$api_page"; then
    die "could not unwrap the doc comments in $(basename "$api_page")"
  fi
}

# Every internal href the compiler emits must resolve, or the reference is
# full of dead links. Cross-check the anchors too, not just the file names.
verify_links() {
  local dir="$1" page href target fragment
  local missing=0
  for page in "$dir"/*.html; do
    [ -e "$page" ] || continue
    while IFS= read -r href; do
      target="${href%%#*}"
      fragment=""
      if [ "$href" != "$target" ]; then fragment="${href#*#}"; fi
      # Same-page anchors (`#foo`) have no file part; nothing to resolve.
      [ -n "$target" ] || continue
      # Only same-directory pages are ours to own.
      case "$target" in http* | //* | mailto:* | javascript:*) continue ;; esac
      # Library pages are named src_<slug>.html; try that fallback
      if [ ! -f "$dir/$target" ] && [ -f "$dir/src_$(basename "$target" .html).html" ]; then
        target="src_$(basename "$target" .html).html"
      fi
      if [ ! -f "$dir/$target" ]; then
        echo "broken link in $(basename "$page"): $href" >&2
        missing=1
        continue
      fi
      if [ -n "$fragment" ] && ! has_id "$dir/$target" "$fragment"; then
        echo "broken anchor in $(basename "$page"): $href" >&2
        missing=1
      fi
    done < <(grep -o 'href="[^"]*"' "$page" | sed 's/^href="//; s/"$//' | sort -u || true)
  done
  [ "$missing" -eq 0 ] || die "link verification failed (a link to a module that is skipped or not under $SOURCE_DIR?)"
}

main() {
  command -v "$KOKA" >/dev/null || die "koka not found on PATH (set KOKA)"
  discover_modules

  # Read the version into a variable first, then parse it in bash: piping
  # `koka --version` into an early-exiting awk can SIGPIPE under `pipefail`,
  # and the exact banner layout ("Koka v3.2.2," vs "Koka 3.2.2,") varies.
  local version_banner koka_version version_re='([0-9]+(\.[0-9]+)+)'
  version_banner="$("$KOKA" --version)"
  [[ $version_banner =~ $version_re ]] || die "could not read the koka version from '$KOKA --version'"
  koka_version="${BASH_REMATCH[1]}"

  # <out-dir> is wiped below, so make sure it holds no sources.
  mkdir -p "$OUT_DIR"
  local out_abs
  out_abs="$(cd "$OUT_DIR" && pwd -P)"
  if [ "$out_abs" = "/" ] ||
    [[ "$SRC_ROOT/" == "$out_abs"/* ]] ||
    [ -n "$(find "$out_abs" -type f -name '*.kk' 2>/dev/null | head -n 1)" ]; then
    die "refusing to use '$OUT_DIR' as out-dir: it contains Koka sources"
  fi

  rm -rf "$BUILD_DIR" "$OUT_DIR"
  mkdir -p "$OUT_DIR/styles"

  local -a extra_flags=()
  read -r -a extra_flags <<<"${KOKA_FLAGS:-}"

  # `-l` builds a library, so a dummy `main` does not become an executable.
  # `--htmlbases` sends every `std/...` cross-reference to the published Koka
  # documentation instead of copying ~6 MB of standard library pages into this
  # repository: those pages describe Koka, not this library, and would drift
  # from the compiler. The compiler's output is kept and shown only if it
  # fails, so a type error is not swallowed. One invocation per module, all
  # into the same build directory.
  local module log
  for module in "${MODULES[@]}"; do
    # Run from the repo root with a relative path, so the page names koka
    # derives from the path (src/a.kk -> src_a) never depend on where the
    # script was started from.
    if ! log="$(cd "$ROOT_DIR" && "$KOKA" -l --html \
      --htmlbases="std=$KOKA_DOC_BASE" \
      --builddir="$BUILD_DIR" \
      ${extra_flags[@]+"${extra_flags[@]}"} \
      "$module" 2>&1)"; then
      printf '%s\n' "$log" >&2
      die "koka failed to build $module"
    fi
  done

  # Only this library's pages are shipped; the compiler also writes the
  # standard library's pages to the build directory, and copying them would add
  # an API that is not ours and can only go stale against the compiler.
  #
  # The compiler links to `<module>.html` but writes `<module>.xmp.html`, so
  # rename on the way out to make the links it generated resolve.
  local slug api_page unwrapped=0
  for module in "${MODULES[@]}"; do
    slug="$(page_slug "$module")"
    cp "$(find_generated "$slug.xmp.html")" "$OUT_DIR/$slug.html"
    cp "$(find_generated "$slug-source.html")" "$OUT_DIR/$slug-source.html"
    api_page="$OUT_DIR/$slug.html"

    retarget_anchors "$OUT_DIR" "$slug.html" "$slug-source.html"
    add_module_anchor "$api_page"
    if unwrap_raw_text_docs "$api_page"; then unwrapped=$((unwrapped + 1)); fi
  done
  # A single module without doc comments is fine; none at all means the
  # compiler's markup changed and this step needs revisiting.
  [ "$unwrapped" -gt 0 ] || die "no <xmp> in any page — the compiler changed its doc markup; revisit unwrap_raw_text_docs"

  write_css "$OUT_DIR/styles/koka.css"
  write_toc "$OUT_DIR/toc.html" "$koka_version"
  write_index "$OUT_DIR/index.html" "$koka_version"

  # The scaffolding links into the generated pages; make sure the whole set is
  # closed before declaring success.
  verify_links "$OUT_DIR"

  echo "wrote $(find "$OUT_DIR" -type f | wc -l | tr -d ' ') files for ${#MODULES[@]} modules to $OUT_DIR"
}

write_css() {
  cat >"$1" <<'CSS'
/* Generated by scripts/build-docs.sh — do not edit.
   Styles the markup emitted by `koka --html`, which is Madoko-flavoured and
   carries no stylesheet of its own. */

:root {
  --bg: #ffffff;
  --bg-raised: #f6f8fa;
  --bg-sunken: #eef1f4;
  --fg: #1f2328;
  --fg-muted: #59636e;
  --fg-faint: #8c959f;
  --border: #d1d9e0;
  --link: #0b62c4;
  --link-hover: #084a94;
  --focus: #0969da;
  --kw: #b3247a;
  --type: #0b62c4;
  --var: #953800;
  --num: #0550ae;
  --comment: #59636e;
  --op: #7a3e9d;
  --code-bg: #f6f8fa;
  --shadow: 0 1px 2px rgba(31, 35, 40, .06), 0 4px 12px rgba(31, 35, 40, .05);
  --mono: "Roboto Mono", ui-monospace, "SFMono-Regular", "SF Mono", Menlo,
          Consolas, "Liberation Mono", monospace;
  --sans: "Nunito", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
          "Helvetica Neue", Arial, sans-serif;
}

@media (prefers-color-scheme: dark) {
  :root {
    --bg: #0d1117;
    --bg-raised: #151b23;
    --bg-sunken: #010409;
    --fg: #e6edf3;
    --fg-muted: #9198a1;
    --fg-faint: #6e7681;
    --border: #3d444d;
    --link: #6cb6ff;
    --link-hover: #a5d2ff;
    --focus: #4493f8;
    --kw: #ff7b9c;
    --type: #6cb6ff;
    --var: #ffa657;
    --num: #79c0ff;
    --comment: #9198a1;
    --op: #d2a8ff;
    --code-bg: #151b23;
    --shadow: 0 1px 2px rgba(1, 4, 9, .4), 0 4px 12px rgba(1, 4, 9, .3);
  }
}

* { box-sizing: border-box; }

body.koka {
  margin: 0 auto;
  padding: 2rem 1.25rem 6rem;
  max-width: 62rem;
  background: var(--bg);
  color: var(--fg);
  font-family: var(--sans);
  font-size: 16px;
  line-height: 1.6;
  overflow-wrap: break-word;
}

a { color: var(--link); text-decoration: none; }

a:hover { color: var(--link-hover); text-decoration: underline; }

/* The scaffolding pages use <code> for inline identifiers; the compiler's own
   pages use <span> classes, so this cannot collide with them. */
code {
  padding: .12em .35em;
  border-radius: 4px;
  background: var(--code-bg);
  font-family: var(--mono);
  font-size: .875em;
}

pre > code { padding: 0; background: none; font-size: inherit; }

h2 {
  margin: 2.25rem 0 .75rem;
  font-size: 1.15rem;
  font-weight: 700;
  letter-spacing: -.01em;
}

h2::before {
  content: "# ";
  color: var(--fg-faint);
  font-family: var(--mono);
  font-weight: 400;
}

:focus-visible {
  outline: 2px solid var(--focus);
  outline-offset: 2px;
  border-radius: 3px;
}

/* ---- module page header ------------------------------------------------ */

body.koka > h1 {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  justify-content: space-between;
  gap: .5rem 1rem;
  margin: 0 0 1.5rem;
  padding-bottom: .75rem;
  border-bottom: 1px solid var(--border);
  font-family: var(--mono);
  font-size: 1.35rem;
  font-weight: 700;
}

.toc-link {
  font-family: var(--sans);
  font-size: .8rem;
  font-weight: 400;
  text-transform: uppercase;
  letter-spacing: .06em;
  color: var(--fg-muted);
}

/* ---- inline table of contents ------------------------------------------ */

div.toc {
  margin: 0 0 2rem;
  padding: 1rem 1.25rem;
  background: var(--bg-raised);
  border: 1px solid var(--border);
  border-radius: 8px;
}

div.toc > ul.toc {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(15rem, 1fr));
  gap: .1rem 1.5rem;
  margin: 0;
  padding: 0;
  list-style: none;
}

div.toc li.nested { padding-left: 1rem; }

/* The marker hangs off the link, not the list item: the link is a block, so a
   pseudo-element on the item would take a row of its own in the grid. */
div.toc li.nested a::before {
  content: "\00b7";
  margin-right: .4rem;
  color: var(--fg-faint);
}

div.toc a {
  display: block;
  padding: .12rem 0;
  font-family: var(--mono);
  font-size: .8rem;
  line-height: 1.5;
  color: var(--fg-muted);
  border-radius: 4px;
}

div.toc a:hover { color: var(--link-hover); text-decoration: none; }

/* ---- declarations ------------------------------------------------------ */

.decl {
  padding: .9rem 0 1rem;
  border-bottom: 1px solid var(--border);
  scroll-margin-top: 1rem;
}

.decl:target { background: var(--bg-raised); box-shadow: 0 0 0 .5rem var(--bg-raised); }

.decl > .header {
  font-family: var(--mono);
  font-size: .875rem;
  line-height: 1.65;
  overflow-x: auto;
}

.decl > .header .def { color: var(--fg); font-weight: 500; }

/* The doc comment's own element. `<xmp>` no longer appears: unwrap_raw_text_docs
   strips it so the compiler's inline markup can render. */
div.doc,
pre.doc {
  display: block;
  margin: .4rem 0 0;
  padding: .1rem 0 .1rem .85rem;
  border-left: 2px solid var(--border);
  font-family: var(--sans);
  font-size: .875rem;
  font-style: normal;
  line-height: 1.6;
  white-space: pre-wrap;
  color: var(--fg-muted);
}

div.nested { margin-left: 1.25rem; }
div.nested1 { margin-left: 1rem; }
div.nested2 { margin-left: .5rem; }

/* ---- syntax highlighting ----------------------------------------------- */

.kw, .decl-fun, .decl-type, .decl-con, .decl-val { color: var(--kw); font-weight: 600; }
.tp, .type, .mo { color: var(--type); }
.tpp, .tv { color: var(--var); font-style: italic; }
.number, .num { color: var(--num); }
.co, .comment { color: var(--comment); font-style: italic; }
.op, .effect, .st { color: var(--op); }
.lq, .param, .tpp, .def > span:not([class]) { color: var(--fg); }
.fslash, .dash { color: var(--fg-faint); }

/* `pp` wraps a type link with its fully qualified path. The compiler's inline
   style hides that path; keep it out of the way but still readable. */
.pp { color: inherit; text-decoration: none; }
.plaincode, a.pp .pc { display: none; }
a.pp:hover > .tp { text-decoration: underline; }
a.pp > .tp { border-bottom: 1px dotted var(--border); }

.last { color: var(--fg-faint); }
.sp { color: var(--fg-muted); }

/* ---- annotated source pages --------------------------------------------- */

body.koka pre.koka.source,
pre.source,
pre.nicecode {
  margin: 0;
  padding: 1.25rem 1.5rem;
  overflow-x: auto;
  background: var(--bg-raised);
  border: 1px solid var(--border);
  border-radius: 8px;
  font-family: var(--mono);
  font-size: .8125rem;
  line-height: 1.7;
  tab-size: 2;
}

pre a.pp { border-bottom: 1px dotted var(--border); }
pre a.pp:hover { background: var(--bg-sunken); }
pre .pc { display: none; }
pre .synopsis { color: var(--fg-muted); }
pre .index { color: var(--kw); font-weight: 600; }

/* ---- line anchors ------------------------------------------------------ */

.decl > .header a.link::after,
pre.source .line-anchor {
  content: "#";
  margin-left: .4rem;
  color: var(--fg-faint);
  opacity: 0;
  font-weight: 400;
  transition: opacity .12s ease-in-out;
}

.decl:hover > .header a.link::after { opacity: 1; }
.decl > .header a.link:hover::after { opacity: 1; color: var(--link); }

/* ---- narrow screens ---------------------------------------------------- */

@media (max-width: 40rem) {
  body.koka { padding: 1.25rem .9rem 4rem; font-size: 15px; }
  body.koka > h1 { font-size: 1.1rem; }
  div.toc > ul.toc { grid-template-columns: 1fr; }
  div.nested { margin-left: .5rem; }
  .decl > .header { font-size: .8125rem; }
  div.doc, pre.doc { padding-left: .6rem; }
}

@media (prefers-reduced-motion: reduce) {
  * { transition: none !important; }
}
CSS
}

# One <li> per module, linking its API page and annotated source.
module_items() {
  local module slug name
  for module in "${MODULES[@]}"; do
    slug="$(page_slug "$module")"
    name="$(html_escape "$(module_name "$module")")"
    printf '<li><a href="%s.html"><code>%s</code></a> — <a href="%s-source.html">source</a></li>\n' \
      "$slug" "$name" "$slug"
  done
}

write_toc() {
  local file="$1" koka_version="$2" project items
  project="$(html_escape "$PROJECT_NAME")"
  items="$(module_items)"
  cat >"$file" <<HTML
<!DOCTYPE html>
<!-- Generated by scripts/build-docs.sh — do not edit. -->
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>$project — contents</title>
<link rel="stylesheet" href="styles/koka.css" />
</head>
<body class="koka doc">
<main>
<section aria-labelledby="this-project">
<h2 id="this-project">$project</h2>
<ul>
<li><a href="index.html">index</a> — overview and installation</li>
</ul>
</section>
<section aria-labelledby="modules">
<h2 id="modules">Modules</h2>
<ul>
$items
</ul>
</section>
<section aria-labelledby="stdlib">
<h2 id="stdlib">Koka standard library</h2>
<p>Types the API links to (<code>list</code>, <code>maybe</code>, <code>int</code>, …) are documented upstream.</p>
<ul>
  <li><a href="$KOKA_DOC_BASE" aria-label="Koka standard library documentation at koka-lang.github.io">Koka standard library ($koka_version)</a></li>
</ul>
</section>
</main>
</body>
</html>
HTML
}

write_index() {
  local file="$1" koka_version="$2" project description items intro=""
  # Only the Koka version is shown: it is read from the compiler itself, and it
  # is what determines what the reference actually describes. The library's
  # own version would be a second source that can drift, for little gain.
  project="$(html_escape "$PROJECT_NAME")"
  description="$(html_escape "$PROJECT_DESCRIPTION")"
  items="$(module_items)"
  # DOCS_INTRO_FILE: optional HTML fragment for intro content
  if [ -f "$ROOT_DIR/$DOCS_INTRO_FILE" ]; then
    intro="$(cat "$ROOT_DIR/$DOCS_INTRO_FILE")"
  fi

  # NB: unquoted heredoc, so a literal `$(...)` in the page text must be
  # written `\$(...)`.
  cat >"$file" <<HTML
<!DOCTYPE html>
<!-- Generated by scripts/build-docs.sh — do not edit. -->
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>$project — Koka library</title>
<meta name="description" content="$description" />
<meta name="theme-color" content="#0b62c4" />
<link rel="stylesheet" href="styles/koka.css" />
</head>
<body class="koka doc">
<main>
<h1>$project</h1>
<p>$description</p>

<p>Go to the <a href="toc.html">table of contents</a>.</p>

$intro

<h2 id="modules">Modules</h2>
<ul>
$items
</ul>

<h2 id="install">Installation</h2>

<p>The flake exposes the library as <code>packages.default</code>, with resolved
paths under <code>kokaLibraries</code> for downstream flakes:</p>

<pre class="koka source">nix build .#packages.x86_64-linux.default

includePath="\$(nix eval --raw .#kokaLibraries.x86_64-linux.$project.includePath)"</pre>
<p>In a consuming flake, <code>nix develop</code> opens a shell that writes
<code>koka.json</code> with the include directories of its dependencies, so
<code>import</code> of this library resolves in editors and the language server.</p>

<h2 id="regenerate">Regenerating these docs</h2>

<p>These pages are produced by the Koka compiler's <code>--html</code> backend
plus the site scaffolding around it (Koka $koka_version). To rebuild:</p>

<pre class="koka source">nix run .#docs            <span class="comment"># writes ./docs in the repo root</span>
nix build .#docs          <span class="comment"># or: result/ in the Nix store</span>
scripts/build-docs.sh docs <span class="comment"># or, from a checkout, if koka is on PATH</span></pre>

</main>
</body>
</html>
HTML
}

main "$@"
