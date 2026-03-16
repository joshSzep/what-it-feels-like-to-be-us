#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
manuscript_file="$repo_root/MANUSCRIPT.md"
cover_file="$repo_root/cover.png"
pdf_file="$repo_root/What-It-Feels-Like-to-Be-Us.pdf"
website_dir="$repo_root/website"
index_file="$website_dir/index.html"
pdf_name="$(basename "$pdf_file")"
cover_name="$(basename "$cover_file")"

require_file() {
  if [[ ! -f "$1" ]]; then
    printf 'Missing required file: %s\n' "$1" >&2
    exit 1
  fi
}

html_escape() {
  printf '%s' "$1" | sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g' \
    -e 's/"/\&quot;/g' \
    -e "s/'/\&#39;/g"
}

format_integer() {
  awk -v value="$1" 'BEGIN {
    formatted = sprintf("%d", value)
    while (sub(/^(-?[0-9]+)([0-9][0-9][0-9])/, "\\1,\\2", formatted)) {}
    print formatted
  }'
}

extract_paragraph_after_heading() {
  local heading="$1"

  awk -v heading="$heading" '
    $0 == heading {
      capture = 1
      next
    }

    capture && /^### / {
      exit
    }

    capture && started && $0 == "" {
      exit
    }

    capture && $0 != "" {
      started = 1

      if (paragraph != "") {
        paragraph = paragraph " " $0
      } else {
        paragraph = $0
      }
    }

    END {
      print paragraph
    }
  ' "$manuscript_file"
}

build_act_markup() {
  awk '
    BEGIN {
      in_act = 0
    }

    /^## / {
      if (in_act) {
        print "            </div>"
        print "          </section>"
      }

      print "          <section class=\"act-card\" data-reveal>"
      print "            <p class=\"act-label\">Act</p>"
      print "            <h3>" substr($0, 4) "</h3>"
      print "            <div class=\"chapter-cluster\">"
      in_act = 1
      next
    }

    /^### / {
      print "              <span class=\"chapter-chip\">" substr($0, 5) "</span>"
    }

    END {
      if (in_act) {
        print "            </div>"
        print "          </section>"
      }
    }
  ' "$manuscript_file"
}

require_file "$manuscript_file"
require_file "$cover_file"

if [[ ! -f "$pdf_file" ]]; then
  pdf_script="$script_dir/create-pdf.sh"

  if [[ ! -f "$pdf_script" ]]; then
    printf 'Missing PDF and no generator found at %s\n' "$pdf_script" >&2
    exit 1
  fi

  bash "$pdf_script"
fi

require_file "$pdf_file"

mkdir -p "$website_dir"
cp -f "$pdf_file" "$website_dir/$pdf_name"
cp -f "$cover_file" "$website_dir/$cover_name"

word_count_raw="$(wc -w < "$manuscript_file" | tr -d '[:space:]')"
word_count="$(format_integer "$word_count_raw")"
chapter_count="$(grep -c '^### ' "$manuscript_file")"
act_count="$(grep -c '^## ' "$manuscript_file")"
pdf_size="$(stat -f '%z' "$pdf_file" | awk '{printf "%.1f MB", $1 / 1048576}')"
updated_stamp="$(date -r "$manuscript_file" '+%B %Y')"

opening_excerpt_raw="$(extract_paragraph_after_heading '### Chapter 01 - Borrowed Weather')"
privacy_excerpt_raw="$(extract_paragraph_after_heading '### Chapter 02 - What Remains Private')"
infrastructure_excerpt_raw="$(extract_paragraph_after_heading '### Chapter 03 - Infrastructure')"

if [[ -z "$opening_excerpt_raw" ]]; then
  opening_excerpt_raw='The line both brothers hesitated over was the same one nearly everyone hesitated over now.'
fi

if [[ -z "$privacy_excerpt_raw" ]]; then
  privacy_excerpt_raw='The room still smelled faintly of wet stems when the weather turned.'
fi

if [[ -z "$infrastructure_excerpt_raw" ]]; then
  infrastructure_excerpt_raw='The first question the girls asked was whether the center had finally replaced the left-side temple contacts that kept slipping into people\''s hair.'
fi

opening_excerpt="$(html_escape "$opening_excerpt_raw")"
privacy_excerpt="$(html_escape "$privacy_excerpt_raw")"
infrastructure_excerpt="$(html_escape "$infrastructure_excerpt_raw")"
act_markup="$(build_act_markup)"

cat > "$index_file" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>What It Feels Like to Be Us</title>
  <meta name="description" content="A freely distributed novel by Joshua Szepietowski about empathy, privacy, mass shared experience, and the quieter possibility that human beings were never fully separate.">
  <style>
    :root {
      --bg: #07131c;
      --bg-deep: #03070d;
      --panel: rgba(10, 22, 33, 0.62);
      --panel-strong: rgba(9, 18, 28, 0.84);
      --line: rgba(214, 194, 160, 0.18);
      --line-strong: rgba(214, 194, 160, 0.36);
      --text: #f5efe6;
      --muted: #c9bfaf;
      --accent: #e4c48f;
      --accent-soft: #8fd8d2;
      --accent-warm: #d8865b;
      --shadow: 0 2rem 6rem rgba(0, 0, 0, 0.35);
      --radius-xl: 32px;
      --radius-lg: 24px;
      --radius-md: 18px;
      --content-width: 1200px;
      --pointer-x: 0px;
      --pointer-y: 0px;
    }

    * {
      box-sizing: border-box;
    }

    html {
      scroll-behavior: smooth;
    }

    body {
      margin: 0;
      min-height: 100vh;
      color: var(--text);
      font-family: "Avenir Next", "Segoe UI", "Helvetica Neue", sans-serif;
      background:
        radial-gradient(circle at 15% 20%, rgba(143, 216, 210, 0.18), transparent 32%),
        radial-gradient(circle at 82% 14%, rgba(228, 196, 143, 0.18), transparent 28%),
        radial-gradient(circle at 50% 110%, rgba(216, 134, 91, 0.22), transparent 38%),
        linear-gradient(180deg, #08131d 0%, #07111b 38%, #050a10 100%);
      overflow-x: hidden;
    }

    body::before {
      content: "";
      position: fixed;
      inset: 0;
      background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='180' height='180' viewBox='0 0 180 180'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='1.15' numOctaves='2' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='180' height='180' filter='url(%23n)' opacity='0.07'/%3E%3C/svg%3E");
      opacity: 0.2;
      pointer-events: none;
      mix-blend-mode: soft-light;
    }

    img {
      max-width: 100%;
      display: block;
    }

    a {
      color: inherit;
      text-decoration: none;
    }

    p {
      margin: 0;
    }

    .page-shell {
      position: relative;
      isolation: isolate;
    }

    .aurora {
      position: fixed;
      width: 52rem;
      height: 52rem;
      border-radius: 999px;
      filter: blur(40px);
      opacity: 0.22;
      pointer-events: none;
      mix-blend-mode: screen;
      animation: drift 18s ease-in-out infinite alternate;
    }

    .aurora.a1 {
      top: -10rem;
      left: -12rem;
      background: radial-gradient(circle, rgba(143, 216, 210, 0.7), transparent 64%);
    }

    .aurora.a2 {
      top: 24rem;
      right: -16rem;
      background: radial-gradient(circle, rgba(228, 196, 143, 0.68), transparent 60%);
      animation-duration: 24s;
    }

    .aurora.a3 {
      bottom: -16rem;
      left: 25%;
      background: radial-gradient(circle, rgba(216, 134, 91, 0.62), transparent 60%);
      animation-duration: 20s;
    }

    .site-header {
      position: sticky;
      top: 0;
      z-index: 10;
      backdrop-filter: blur(18px);
      background: linear-gradient(180deg, rgba(4, 10, 16, 0.82), rgba(4, 10, 16, 0.26));
      border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    }

    .site-header-inner {
      width: min(calc(100% - 2rem), var(--content-width));
      margin: 0 auto;
      min-height: 4.5rem;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 1rem;
    }

    .brand {
      display: flex;
      flex-direction: column;
      gap: 0.2rem;
    }

    .brand-title {
      font-family: "Iowan Old Style", "Palatino Linotype", "Book Antiqua", "URW Palladio L", serif;
      font-size: 1rem;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }

    .brand-subtitle {
      color: var(--muted);
      font-size: 0.78rem;
      letter-spacing: 0.16em;
      text-transform: uppercase;
    }

    .nav-actions {
      display: flex;
      flex-wrap: wrap;
      gap: 0.75rem;
      align-items: center;
    }

    .nav-link,
    .button,
    .button-secondary {
      border-radius: 999px;
      padding: 0.85rem 1.2rem;
      font-size: 0.92rem;
      transition: transform 180ms ease, background 180ms ease, border-color 180ms ease, box-shadow 180ms ease;
      will-change: transform;
    }

    .nav-link {
      color: var(--muted);
      border: 1px solid transparent;
    }

    .nav-link:hover,
    .nav-link:focus-visible {
      color: var(--text);
      border-color: rgba(255, 255, 255, 0.08);
      background: rgba(255, 255, 255, 0.03);
      outline: none;
    }

    .button,
    .button-secondary {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 0.55rem;
      font-weight: 600;
      letter-spacing: 0.02em;
    }

    .button {
      background: linear-gradient(135deg, rgba(228, 196, 143, 0.92), rgba(216, 134, 91, 0.9));
      color: #130d08;
      box-shadow: 0 1.5rem 3rem rgba(216, 134, 91, 0.18);
    }

    .button-secondary {
      border: 1px solid rgba(255, 255, 255, 0.12);
      background: rgba(255, 255, 255, 0.03);
      color: var(--text);
      box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.03);
    }

    .button:hover,
    .button-secondary:hover,
    .button:focus-visible,
    .button-secondary:focus-visible {
      transform: translateY(-2px);
      outline: none;
    }

    .main {
      width: min(calc(100% - 2rem), var(--content-width));
      margin: 0 auto;
      padding: 4.5rem 0 6rem;
    }

    .hero {
      position: relative;
      display: grid;
      grid-template-columns: minmax(0, 1.15fr) minmax(300px, 0.85fr);
      gap: clamp(2rem, 4vw, 5rem);
      align-items: center;
      min-height: calc(100vh - 8rem);
      padding: 4rem 0 3rem;
    }

    .hero-copy,
    .hero-visual,
    .section-card,
    .excerpt-card,
    .act-card,
    .download-panel {
      opacity: 0;
      transform: translateY(24px);
      transition: opacity 720ms ease, transform 720ms ease;
    }

    .is-visible {
      opacity: 1;
      transform: translateY(0);
    }

    .eyebrow,
    .section-label,
    .stat-label,
    .act-label {
      color: var(--accent-soft);
      font-size: 0.82rem;
      letter-spacing: 0.28em;
      text-transform: uppercase;
    }

    .hero h1 {
      margin: 1rem 0 1.4rem;
      font-family: "Iowan Old Style", "Palatino Linotype", "Book Antiqua", "URW Palladio L", serif;
      font-size: clamp(3.4rem, 8vw, 6.8rem);
      line-height: 0.92;
      letter-spacing: -0.04em;
      max-width: 10ch;
      text-wrap: balance;
    }

    .hero h1 .line-soft {
      display: block;
      color: rgba(245, 239, 230, 0.78);
    }

    .lede {
      max-width: 38rem;
      font-size: clamp(1.08rem, 2vw, 1.3rem);
      line-height: 1.75;
      color: var(--muted);
    }

    .hero-actions {
      display: flex;
      flex-wrap: wrap;
      gap: 1rem;
      margin-top: 2rem;
    }

    .stats {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 1rem;
      margin-top: 2.25rem;
      max-width: 42rem;
    }

    .stat {
      padding: 1.15rem 1.2rem;
      border-radius: var(--radius-md);
      background: linear-gradient(180deg, rgba(255, 255, 255, 0.06), rgba(255, 255, 255, 0.02));
      border: 1px solid rgba(255, 255, 255, 0.08);
      box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.06);
    }

    .stat-value {
      margin-top: 0.45rem;
      font-size: clamp(1.5rem, 4vw, 2.4rem);
      font-family: "Iowan Old Style", "Palatino Linotype", "Book Antiqua", serif;
    }

    .hero-visual {
      position: relative;
      min-height: 32rem;
      display: grid;
      place-items: center;
    }

    .sky {
      position: absolute;
      inset: 0;
      overflow: hidden;
      pointer-events: none;
    }

    .mote {
      position: absolute;
      left: 0;
      top: 0;
      width: var(--size);
      height: var(--size);
      border-radius: 999px;
      background: radial-gradient(circle, rgba(255, 255, 255, 0.95), rgba(255, 255, 255, 0));
      opacity: 0.38;
      transform: translate3d(var(--x), var(--y), 0);
      animation: mote-float var(--duration) ease-in-out infinite;
      animation-delay: var(--delay);
    }

    .cover-stack {
      position: relative;
      width: min(100%, 30rem);
      display: grid;
      place-items: center;
      transform: translate3d(calc(var(--pointer-x) * 0.35), calc(var(--pointer-y) * 0.35), 0);
      transition: transform 220ms ease-out;
    }

    .cover-halo,
    .cover-glow {
      position: absolute;
      inset: auto;
      border-radius: 999px;
      pointer-events: none;
    }

    .cover-halo {
      width: 22rem;
      height: 22rem;
      background: radial-gradient(circle, rgba(143, 216, 210, 0.24), rgba(228, 196, 143, 0.04) 62%, transparent 74%);
      filter: blur(12px);
      animation: pulse 8s ease-in-out infinite;
    }

    .cover-glow {
      width: 28rem;
      height: 28rem;
      background: radial-gradient(circle, rgba(216, 134, 91, 0.18), transparent 62%);
      filter: blur(20px);
      animation: pulse 10s ease-in-out infinite reverse;
    }

    .orbit {
      position: absolute;
      inset: 50% auto auto 50%;
      border-radius: 999px;
      border: 1px solid rgba(255, 255, 255, 0.1);
      transform: translate(-50%, -50%);
      pointer-events: none;
    }

    .orbit.o1 {
      width: 23rem;
      height: 23rem;
      animation: slow-spin 24s linear infinite;
    }

    .orbit.o2 {
      width: 29rem;
      height: 29rem;
      border-color: rgba(143, 216, 210, 0.16);
      animation: slow-spin 40s linear infinite reverse;
    }

    .orbit.o3 {
      width: 35rem;
      height: 35rem;
      border-color: rgba(228, 196, 143, 0.1);
      animation: slow-spin 55s linear infinite;
    }

    .cover-frame {
      position: relative;
      display: block;
      width: min(100%, 22rem);
      border-radius: 28px;
      overflow: hidden;
      box-shadow:
        0 2rem 5rem rgba(0, 0, 0, 0.45),
        0 0 0 1px rgba(255, 255, 255, 0.1),
        inset 0 1px 0 rgba(255, 255, 255, 0.18);
      transform: rotate(-4deg);
      transition: transform 260ms ease, box-shadow 260ms ease;
      background: rgba(255, 255, 255, 0.04);
    }

    .cover-frame::after {
      content: "";
      position: absolute;
      inset: 0;
      background: linear-gradient(145deg, rgba(255, 255, 255, 0.2), transparent 28%, transparent 68%, rgba(255, 255, 255, 0.12));
      pointer-events: none;
    }

    .cover-frame:hover,
    .cover-frame:focus-visible {
      transform: rotate(-2deg) translateY(-6px) scale(1.01);
      box-shadow:
        0 2.4rem 6rem rgba(0, 0, 0, 0.52),
        0 0 0 1px rgba(255, 255, 255, 0.14),
        inset 0 1px 0 rgba(255, 255, 255, 0.2);
      outline: none;
    }

    .cover-reflection {
      position: absolute;
      width: 65%;
      height: 2rem;
      bottom: -1.4rem;
      border-radius: 999px;
      background: radial-gradient(circle, rgba(228, 196, 143, 0.22), transparent 65%);
      filter: blur(12px);
      opacity: 0.9;
    }

    .floating-note {
      position: absolute;
      max-width: 13rem;
      padding: 0.95rem 1rem;
      border-radius: 18px;
      background: rgba(8, 16, 25, 0.5);
      border: 1px solid rgba(255, 255, 255, 0.08);
      color: var(--muted);
      font-size: 0.92rem;
      line-height: 1.55;
      backdrop-filter: blur(14px);
      box-shadow: var(--shadow);
    }

    .floating-note strong {
      display: block;
      margin-bottom: 0.35rem;
      color: var(--text);
      font-size: 0.76rem;
      letter-spacing: 0.18em;
      text-transform: uppercase;
    }

    .note-a {
      top: 7%;
      right: 6%;
      animation: drift-note 10s ease-in-out infinite;
    }

    .note-b {
      bottom: 10%;
      left: 0;
      animation: drift-note 12s ease-in-out infinite reverse;
    }

    .section {
      position: relative;
      padding: 3.6rem 0;
    }

    .section-heading {
      max-width: 48rem;
      margin-bottom: 2rem;
    }

    .section-heading h2 {
      margin: 0.75rem 0 1rem;
      font-family: "Iowan Old Style", "Palatino Linotype", "Book Antiqua", serif;
      font-size: clamp(2.2rem, 5vw, 4rem);
      line-height: 1;
      letter-spacing: -0.04em;
      text-wrap: balance;
    }

    .section-heading p {
      color: var(--muted);
      font-size: 1.05rem;
      line-height: 1.8;
    }

    .quote-panel {
      position: relative;
      padding: clamp(2rem, 4vw, 3rem);
      border-radius: var(--radius-xl);
      background: linear-gradient(180deg, rgba(255, 255, 255, 0.06), rgba(255, 255, 255, 0.02));
      border: 1px solid rgba(255, 255, 255, 0.09);
      box-shadow: var(--shadow);
      overflow: hidden;
    }

    .quote-panel::before {
      content: "";
      position: absolute;
      inset: -35% 45% auto -10%;
      height: 16rem;
      background: radial-gradient(circle, rgba(143, 216, 210, 0.22), transparent 70%);
      filter: blur(12px);
      pointer-events: none;
    }

    .quote-panel blockquote {
      margin: 1.2rem 0 0;
      max-width: 17ch;
      font-family: "Iowan Old Style", "Palatino Linotype", "Book Antiqua", serif;
      font-size: clamp(2rem, 4vw, 3.8rem);
      line-height: 1.05;
      letter-spacing: -0.04em;
    }

    .quote-panel p {
      color: var(--muted);
      max-width: 44rem;
      line-height: 1.75;
      margin-top: 1.4rem;
      font-size: 1.05rem;
    }

    .story-grid,
    .excerpt-grid,
    .acts-grid {
      display: grid;
      gap: 1.25rem;
    }

    .story-grid {
      grid-template-columns: repeat(3, minmax(0, 1fr));
    }

    .excerpt-grid {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }

    .acts-grid {
      grid-template-columns: repeat(3, minmax(0, 1fr));
    }

    .section-card,
    .excerpt-card,
    .act-card,
    .download-panel {
      padding: 1.5rem;
      border-radius: var(--radius-lg);
      background: linear-gradient(180deg, rgba(255, 255, 255, 0.06), rgba(255, 255, 255, 0.025));
      border: 1px solid rgba(255, 255, 255, 0.08);
      box-shadow: var(--shadow);
      position: relative;
      overflow: hidden;
    }

    .section-card::before,
    .excerpt-card::before,
    .act-card::before,
    .download-panel::before {
      content: "";
      position: absolute;
      inset: auto -10% 70% auto;
      width: 12rem;
      height: 12rem;
      background: radial-gradient(circle, rgba(255, 255, 255, 0.08), transparent 68%);
      pointer-events: none;
    }

    .section-card h3,
    .act-card h3,
    .download-panel h2 {
      margin: 0.7rem 0 0.8rem;
      font-family: "Iowan Old Style", "Palatino Linotype", "Book Antiqua", serif;
      font-size: clamp(1.45rem, 3vw, 2rem);
      line-height: 1.05;
    }

    .section-card p,
    .act-card p,
    .excerpt-card p,
    .download-panel p {
      color: var(--muted);
      line-height: 1.75;
      font-size: 0.98rem;
    }

    .excerpt-card {
      min-height: 100%;
    }

    .excerpt-card .excerpt-kicker {
      color: var(--accent);
      font-size: 0.78rem;
      letter-spacing: 0.18em;
      text-transform: uppercase;
    }

    .excerpt-card blockquote {
      margin: 0.8rem 0 0;
      font-family: "Iowan Old Style", "Palatino Linotype", "Book Antiqua", serif;
      font-size: clamp(1.35rem, 3vw, 2rem);
      line-height: 1.3;
      letter-spacing: -0.02em;
    }

    .chapter-cluster {
      display: flex;
      flex-wrap: wrap;
      gap: 0.75rem;
      margin-top: 1.35rem;
    }

    .chapter-chip {
      display: inline-flex;
      align-items: center;
      min-height: 2.2rem;
      padding: 0.5rem 0.85rem;
      border-radius: 999px;
      border: 1px solid rgba(255, 255, 255, 0.08);
      background: rgba(255, 255, 255, 0.03);
      color: rgba(245, 239, 230, 0.88);
      font-size: 0.88rem;
      line-height: 1.3;
    }

    .download-panel {
      display: grid;
      grid-template-columns: minmax(0, 1.1fr) minmax(220px, 0.75fr);
      gap: 2rem;
      align-items: center;
    }

    .download-meta {
      display: flex;
      flex-wrap: wrap;
      gap: 0.75rem;
      margin-top: 1.2rem;
    }

    .download-meta span {
      display: inline-flex;
      align-items: center;
      padding: 0.55rem 0.8rem;
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid rgba(255, 255, 255, 0.08);
      color: var(--muted);
      font-size: 0.9rem;
    }

    .mini-cover {
      width: min(100%, 14rem);
      margin-left: auto;
      border-radius: 22px;
      overflow: hidden;
      box-shadow: 0 1.6rem 4rem rgba(0, 0, 0, 0.4);
      border: 1px solid rgba(255, 255, 255, 0.1);
    }

    .site-footer {
      width: min(calc(100% - 2rem), var(--content-width));
      margin: 0 auto;
      padding: 0 0 3rem;
      display: flex;
      flex-wrap: wrap;
      gap: 1rem;
      align-items: center;
      justify-content: space-between;
      color: rgba(201, 191, 175, 0.78);
      font-size: 0.92rem;
    }

    .footer-links {
      display: flex;
      flex-wrap: wrap;
      gap: 1rem;
    }

    .footer-links a {
      color: rgba(245, 239, 230, 0.86);
    }

    .footer-links a:hover,
    .footer-links a:focus-visible {
      color: var(--accent);
      outline: none;
    }

    ::selection {
      background: rgba(228, 196, 143, 0.28);
      color: #fff7eb;
    }

    @keyframes drift {
      from {
        transform: translate3d(0, 0, 0) scale(1);
      }
      to {
        transform: translate3d(2rem, -1.5rem, 0) scale(1.06);
      }
    }

    @keyframes pulse {
      0%,
      100% {
        transform: scale(0.96);
        opacity: 0.75;
      }
      50% {
        transform: scale(1.04);
        opacity: 1;
      }
    }

    @keyframes slow-spin {
      from {
        transform: translate(-50%, -50%) rotate(0deg);
      }
      to {
        transform: translate(-50%, -50%) rotate(360deg);
      }
    }

    @keyframes mote-float {
      0%,
      100% {
        transform: translate3d(var(--x), var(--y), 0) scale(0.9);
        opacity: 0.16;
      }
      50% {
        transform: translate3d(var(--x), calc(var(--y) - 26px), 0) scale(1.1);
        opacity: 0.52;
      }
    }

    @keyframes drift-note {
      0%,
      100% {
        transform: translateY(0px);
      }
      50% {
        transform: translateY(-10px);
      }
    }

    @media (max-width: 1080px) {
      .hero {
        grid-template-columns: 1fr;
        min-height: auto;
        padding-top: 2rem;
      }

      .hero h1 {
        max-width: 12ch;
      }

      .hero-visual {
        order: -1;
        min-height: 30rem;
      }

      .story-grid,
      .acts-grid,
      .excerpt-grid,
      .download-panel {
        grid-template-columns: 1fr;
      }

      .mini-cover {
        margin-left: 0;
      }
    }

    @media (max-width: 760px) {
      .site-header-inner {
        min-height: auto;
        padding: 0.9rem 0;
        align-items: flex-start;
        flex-direction: column;
      }

      .main {
        padding-top: 2rem;
      }

      .hero {
        padding-top: 1rem;
      }

      .hero h1 {
        font-size: clamp(2.8rem, 16vw, 4.3rem);
      }

      .stats {
        grid-template-columns: 1fr;
      }

      .quote-panel blockquote {
        max-width: none;
      }

      .floating-note {
        position: relative;
        inset: auto;
        max-width: none;
      }

      .hero-visual {
        gap: 1rem;
        align-content: center;
      }
    }

    @media (prefers-reduced-motion: reduce) {
      html {
        scroll-behavior: auto;
      }

      *,
      *::before,
      *::after {
        animation: none !important;
        transition-duration: 0ms !important;
      }

      .hero-copy,
      .hero-visual,
      .section-card,
      .excerpt-card,
      .act-card,
      .download-panel {
        opacity: 1;
        transform: none;
      }
    }
  </style>
</head>
<body>
  <div class="page-shell">
    <div class="aurora a1"></div>
    <div class="aurora a2"></div>
    <div class="aurora a3"></div>

    <header class="site-header">
      <div class="site-header-inner">
        <div class="brand">
          <span class="brand-title">What It Feels Like to Be Us</span>
          <span class="brand-subtitle">A novel by Joshua Szepietowski</span>
        </div>
        <nav class="nav-actions" aria-label="Primary">
          <a class="nav-link" href="#world">The Novel</a>
          <a class="nav-link" href="#acts">The Structure</a>
          <a class="nav-link" href="#download">Read Free</a>
          <a class="button-secondary" href="$pdf_name" target="_blank" rel="noreferrer">Open PDF</a>
        </nav>
      </div>
    </header>

    <main class="main">
      <section class="hero" id="top">
        <div class="hero-copy" data-reveal>
          <p class="eyebrow">Freely distributed novel · $updated_stamp</p>
          <h1>
            What It Feels<br>
            <span class="line-soft">Like to Be Us</span>
          </h1>
          <p class="lede">A literary speculative novel about empathy, privacy, and the moment shared feeling grows beyond one-to-one exchange into something vast, controversial, and quietly transcendent.</p>
          <div class="hero-actions">
            <a class="button" href="$pdf_name" download>Download the novel</a>
            <a class="button-secondary" href="#excerpt">Read the opening pulse</a>
          </div>
          <div class="stats" aria-label="Book statistics">
            <article class="stat">
              <p class="stat-label">Acts</p>
              <p class="stat-value">$act_count</p>
            </article>
            <article class="stat">
              <p class="stat-label">Chapters</p>
              <p class="stat-value">$chapter_count</p>
            </article>
            <article class="stat">
              <p class="stat-label">Words</p>
              <p class="stat-value">$word_count</p>
            </article>
          </div>
        </div>

        <div class="hero-visual" data-reveal>
          <div class="sky" aria-hidden="true"></div>
          <div class="cover-stack">
            <div class="cover-halo"></div>
            <div class="cover-glow"></div>
            <div class="orbit o1"></div>
            <div class="orbit o2"></div>
            <div class="orbit o3"></div>
            <a class="cover-frame" href="$pdf_name" target="_blank" rel="noreferrer" aria-label="Open the PDF edition of What It Feels Like to Be Us">
              <img src="$cover_name" alt="Cover of What It Feels Like to Be Us" loading="eager">
            </a>
            <div class="cover-reflection"></div>
          </div>
          <aside class="floating-note note-a">
            <strong>The Movement</strong>
            From you, through me, toward us.
          </aside>
          <aside class="floating-note note-b">
            <strong>The Promise</strong>
            Hope without naivete. Connection without the erasure of self.
          </aside>
        </div>
      </section>

      <section class="section" id="excerpt">
        <div class="quote-panel" data-reveal>
          <p class="section-label">Opening pulse</p>
          <blockquote>$opening_excerpt</blockquote>
          <p>The novel begins in a room designed for care rather than spectacle, then widens into a world where empath technology has escaped regulation, entered ordinary life, and started testing the moral limits of shared feeling at planetary scale.</p>
        </div>
      </section>

      <section class="section" id="world">
        <div class="section-heading" data-reveal>
          <p class="section-label">The novel</p>
          <h2>Not a techno-thriller. Not a utopian fantasy. Something more intimate and more dangerous.</h2>
          <p>This is the final movement of a trilogy about consciousness, exposure, and interconnection. It asks what happens after empath technology leaves the lab, crosses borders, enters schools and clinics and underground scenes, and finally becomes capable of mass shared emotional experience.</p>
        </div>
        <div class="story-grid">
          <article class="section-card" data-reveal>
            <p class="section-label">Scale</p>
            <h3>Shared feeling, no longer private or small</h3>
            <p>What begins as bounded emotional transfer becomes civic infrastructure, black-market temptation, and global argument. The frontier is no longer whether we can emote. It is what happens when entire populations begin to do it.</p>
          </article>
          <article class="section-card" data-reveal>
            <p class="section-label">Tension</p>
            <h3>Empathy as power, care, boundary, and risk</h3>
            <p>The novel stays with consent, opacity, regulation, and the ethical cost of turning another person\'s interior life into access. Shared feeling can heal. It can also expose, manipulate, and overwhelm.</p>
          </article>
          <article class="section-card" data-reveal>
            <p class="section-label">Promise</p>
            <h3>An earned form of transcendence</h3>
            <p>The final movement is not toward spectacle. It moves toward awe, equanimity, and the quieter recognition that separateness may be necessary without ever having been absolute.</p>
          </article>
        </div>
      </section>

      <section class="section">
        <div class="section-heading" data-reveal>
          <p class="section-label">From the manuscript</p>
          <h2>Three textures of the world</h2>
          <p>The book moves from intimate rooms into institutional friction, then toward public systems trying and failing to look neutral while the human stakes keep breaking through.</p>
        </div>
        <div class="excerpt-grid">
          <article class="excerpt-card" data-reveal>
            <p class="excerpt-kicker">What remains private</p>
            <blockquote>$privacy_excerpt</blockquote>
          </article>
          <article class="excerpt-card" data-reveal>
            <p class="excerpt-kicker">Infrastructure</p>
            <blockquote>$infrastructure_excerpt</blockquote>
          </article>
        </div>
      </section>

      <section class="section" id="acts">
        <div class="section-heading" data-reveal>
          <p class="section-label">Three acts</p>
          <h2>A braided novel that widens, converges, and returns with more quiet than certainty.</h2>
          <p>The architecture of the book mirrors its emotional movement: bounded rooms, growing social weather, and the afterimage of a signal that changes what distance means without dissolving individuality.</p>
        </div>
        <div class="acts-grid">
$act_markup
        </div>
      </section>

      <section class="section" id="download">
        <div class="download-panel" data-reveal>
          <div>
            <p class="section-label">Read free</p>
            <h2>The full novel is available as a freely distributed PDF.</h2>
            <p>Open it in the browser, download it directly, or share the file. The site ships with the finished cover and the PDF edition so the launch page can be dropped onto static hosting without any additional build step.</p>
            <div class="hero-actions">
              <a class="button" href="$pdf_name" download>Download PDF</a>
              <a class="button-secondary" href="$pdf_name" target="_blank" rel="noreferrer">Read in browser</a>
            </div>
            <div class="download-meta" aria-label="Edition details">
              <span>Free PDF edition</span>
              <span>$pdf_size</span>
              <span>$updated_stamp</span>
            </div>
          </div>
          <div class="mini-cover">
            <img src="$cover_name" alt="What It Feels Like to Be Us cover thumbnail" loading="lazy">
          </div>
        </div>
      </section>
    </main>

    <footer class="site-footer">
      <p>What It Feels Like to Be Us by Joshua Szepietowski.</p>
      <div class="footer-links">
        <a href="#top">Back to top</a>
        <a href="$pdf_name" target="_blank" rel="noreferrer">Open the PDF</a>
        <a href="$cover_name" target="_blank" rel="noreferrer">View the cover</a>
      </div>
    </footer>
  </div>

  <script>
    (function () {
      var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      var revealNodes = document.querySelectorAll('[data-reveal]');

      if (!reduceMotion && 'IntersectionObserver' in window) {
        var observer = new IntersectionObserver(function (entries) {
          entries.forEach(function (entry) {
            if (entry.isIntersecting) {
              entry.target.classList.add('is-visible');
              observer.unobserve(entry.target);
            }
          });
        }, {
          threshold: 0.18,
          rootMargin: '0px 0px -8% 0px'
        });

        revealNodes.forEach(function (node) {
          observer.observe(node);
        });
      } else {
        revealNodes.forEach(function (node) {
          node.classList.add('is-visible');
        });
      }

      var sky = document.querySelector('.sky');

      if (sky && !reduceMotion) {
        for (var index = 0; index < 36; index += 1) {
          var mote = document.createElement('span');
          mote.className = 'mote';
          mote.style.setProperty('--x', (Math.random() * 100).toFixed(2) + '%');
          mote.style.setProperty('--y', (Math.random() * 100).toFixed(2) + '%');
          mote.style.setProperty('--size', (Math.random() * 3 + 1.2).toFixed(2) + 'px');
          mote.style.setProperty('--duration', (Math.random() * 8 + 8).toFixed(2) + 's');
          mote.style.setProperty('--delay', (-Math.random() * 12).toFixed(2) + 's');
          sky.appendChild(mote);
        }
      }

      if (!reduceMotion) {
        window.addEventListener('pointermove', function (event) {
          var x = ((event.clientX / window.innerWidth) - 0.5) * 24;
          var y = ((event.clientY / window.innerHeight) - 0.5) * 18;
          document.documentElement.style.setProperty('--pointer-x', x.toFixed(2) + 'px');
          document.documentElement.style.setProperty('--pointer-y', y.toFixed(2) + 'px');
        }, { passive: true });
      }
    }());
  </script>
</body>
</html>
EOF

printf 'Wrote %s\n' "$index_file"
printf 'Copied %s\n' "$website_dir/$pdf_name"
printf 'Copied %s\n' "$website_dir/$cover_name"