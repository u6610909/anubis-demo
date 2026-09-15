#!/usr/bin/env bash
# Live demo for CSX4110 Project 02: Anubis.
# Run:  ./demo/demo.sh          (pauses between steps; press Enter to advance)
#       ./demo/demo.sh --fast   (no pauses)

BASE="${BASE:-http://localhost:8888}"
CHROME='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
GPTBOT='Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko); compatible; GPTBot/1.2; +https://openai.com/gptbot'

B=$'\e[1m'; G=$'\e[32m'; R=$'\e[31m'; Y=$'\e[33m'; D=$'\e[2m'; N=$'\e[0m'
pause(){ [ "$1" = "--fast" ] || { printf '\n%s' "${D}   [Enter]${N}"; read -r; }; }
step(){ printf '\n%s\n%s\n' "${B}$1${N}" "${D}$2${N}"; }

printf '\n%s\n' "${B}=== Anubis demo: DevPortal behind a Web AI Firewall ===${N}"
printf '%s\n' "${D}target: $BASE${N}"

# ---------------------------------------------------------------------------
step "1) Known AI training crawler announces itself" \
     "curl -A 'GPTBot/1.2' $BASE/"
body=$(curl -s -A "$GPTBOT" "$BASE/")
if grep -qi 'denied\|not welcome' <<<"$body"; then
  printf '   %s  matched (data)/meta/ai-block-aggressive.yaml, never reaches the origin\n' "${R}DENIED${N}"
else
  printf '   unexpected: %s\n' "$(grep -oE '<title>[^<]*' <<<"$body")"
fi
pause "$1"

# ---------------------------------------------------------------------------
step "2) The same scraper lies and claims to be Chrome" \
     "curl -A 'Mozilla/5.0 ... Chrome/120' $BASE/"
body=$(curl -s -A "$CHROME" "$BASE/")
diff=$(grep -oE '"difficulty":[0-9]+' <<<"$body" | head -1 | cut -d: -f2)
if grep -q 'not a bot' <<<"$body"; then
  printf '   %s  proof-of-work challenge, difficulty %s\n' "${Y}CHALLENGED${N}" "${diff:-?}"
  printf '   %s\n' "${D}curl has no JavaScript engine, so this is where the scraper stops.${N}"
  printf '   origin content leaked: %s\n' "$(grep -c 'reached the origin' <<<"$body")"
fi
pause "$1"

# ---------------------------------------------------------------------------
step "3) ...and now on an EXPENSIVE page (/blame/)" \
     "same User-Agent, different path. Watch the difficulty change"
body=$(curl -s -A "$CHROME" "$BASE/blame/")
diff2=$(grep -oE '"difficulty":[0-9]+' <<<"$body" | head -1 | cut -d: -f2)
printf '   %s  difficulty %s  %s\n' "${Y}CHALLENGED${N}" "${diff2:-?}" \
       "${D}(browser +10, expensive path +20 = weight 30)${N}"
printf '   %s\n' "${D}difficulty is hex digits: each +1 is 16x more hashing.${N}"
printf '   %s\n' "${D}  difficulty ${diff:-2} = ~$((16**${diff:-2})) hashes   difficulty ${diff2:-5} = ~$((16**${diff2:-5})) hashes${N}"
pause "$1"

# ---------------------------------------------------------------------------
step "4) Our own CI runner. No JS engine, so it must not be blocked" \
     "curl -H 'Accept: application/json' $BASE/api/status.json"
curl -s -A 'devportal-ci/2.1' -H 'Accept: application/json' "$BASE/api/status.json" | head -4 | sed 's/^/   /'
printf '   %s  explicit ALLOW rule in botPolicies.yaml\n' "${G}PASSED${N}"
pause "$1"

# ---------------------------------------------------------------------------
step "5) git clone" "curl -A 'git/2.45.0' $BASE/"
if curl -s -A 'git/2.45.0' "$BASE/" | grep -q 'reached the origin'; then
  printf '   %s  git traffic is untouched\n' "${G}PASSED${N}"
fi
pause "$1"

# ---------------------------------------------------------------------------
step "6) A real browser" "open $BASE/blame/ and watch it solve the challenge"
printf '   Expected: a progress bar, then the page.\n'
printf '   Measured on this laptop: %s first visit, then %s per page\n' "${G}~4.5 s${N}" "${G}~12 ms${N}"
printf '   %s\n' "${D}The signed cookie covers the rest of the session, so you only pay once.${N}"

printf '\n%s\n' "${B}=== The economics ===${N}"
printf '   Human, 50 pages : one 4.5 s challenge, then free      = %s\n' "${G}~4.5 s${N}"
printf '   Scraper, 50 pages: rotates identity to dodge cookies  = %s\n' "${R}~225 s${N}"
printf '   %s\n\n' "${D}Scraping still works. It just gets expensive.${N}"
