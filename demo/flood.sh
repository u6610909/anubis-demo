#!/usr/bin/env bash
# Send many bots at the demo at the same time and count what happens.
#   ./demo/flood.sh              600 requests, 50 at a time
#   ./demo/flood.sh 2000 100     2000 requests, 100 at a time
#
# At the end it also counts how many requests really reached the website
# (nginx). If Anubis is doing its job, that number should match "let in".
#
# Note: every request comes from this one computer, so this tests many
# requests at once, not many different IP addresses.

cd "$(dirname "$0")/.." || exit 1
TOTAL="${1:-600}"
PARALLEL="${2:-50}"
BASE="${BASE:-http://localhost:8888}"

# name | name tag (User-Agent) | page | extra header
BOTS='GPTBot|Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko); compatible; GPTBot/1.2; +https://openai.com/gptbot|/|
ClaudeBot|Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; ClaudeBot/1.0; +claudebot@anthropic.com)|/|
HeadlessChrome|Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/120.0.0.0 Safari/537.36|/|
fake Chrome /|Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36|/|
fake Chrome /blame/|Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36|/blame/|
fake Googlebot|Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)|/|
our CI runner|devportal-ci/2.1|/api/status.json|Accept: application/json
git|git/2.45.0|/|'

hit() {
  IFS='|' read -r name ua path hdr <<<"$1"
  if [ -n "$hdr" ]; then
    out=$(curl -s --max-time 20 -w '\n%{http_code} %{time_total}' -A "$ua" -H "$hdr" "$BASE$path")
  else
    out=$(curl -s --max-time 20 -w '\n%{http_code} %{time_total}' -A "$ua" "$BASE$path")
  fi
  body=${out%$'\n'*}; tail=${out##*$'\n'}; t=${tail#* }
  if   grep -q 'reached the origin\|"status": "ok"' <<<"$body"; then r="let in"
  elif grep -qi 'denied' <<<"$body";                          then r="blocked"
  elif grep -q 'not a bot' <<<"$body";                         then r="puzzle"
  # Anubis sometimes spot-checks a "browser" for gzip support. Real browsers
  # always have it, plain curl does not, so Anubis refuses it as a fake.
  elif grep -q 'ensure your browser is up to date' <<<"$body";  then r="caught fake"
  else r="error"; fi
  printf '%s|%s|%s\n' "$name" "$r" "$t"
}
export -f hit; export BASE

count_origin() { docker compose logs --no-log-prefix devportal 2>/dev/null | grep -c '"GET '; }

before=$(count_origin)
printf 'Sending %s requests, %s at a time, to %s ...\n' "$TOTAL" "$PARALLEL" "$BASE"
start=$(date +%s)

n=$(grep -c . <<<"$BOTS")
results=$(for ((i=0; i<TOTAL; i++)); do sed -n "$(( i % n + 1 ))p" <<<"$BOTS"; done |
          tr '\n' '\0' | xargs -0 -P "$PARALLEL" -I{} bash -c 'hit "$1"' _ {})

secs=$(( $(date +%s) - start )); [ "$secs" -lt 1 ] && secs=1
sleep 1
reached=$(( $(count_origin) - before ))

echo
printf '%-20s %8s %8s %8s %12s %6s\n' "bot" "blocked" "puzzle" "let in" "caught fake" "error"
awk -F'|' '{ c[$1,$2]++; seen[$1]=1 }
  END { for (b in seen) printf "%-20s %8d %8d %8d %12d %6d\n", b, c[b,"blocked"], c[b,"puzzle"], c[b,"let in"], c[b,"caught fake"], c[b,"error"] }' <<<"$results" | sort
awk -F'|' '{ tot[$2]++; sum+=$3; if ($3>max) max=$3; all++ }
  END { printf "%-20s %8d %8d %8d %12d %6d\n", "TOTAL", tot["blocked"], tot["puzzle"], tot["let in"], tot["caught fake"], tot["error"]
        printf "\naverage answer time: %.0f ms   slowest: %.0f ms\n", sum/all*1000, max*1000 }' <<<"$results"
letin=$(grep -c '|let in|' <<<"$results")
printf 'finished in about %s s (%s requests per second)\n\n' "$secs" "$(( TOTAL / secs ))"
printf 'Requests that reached the website (nginx log): %s\n' "$reached"
printf 'Requests Anubis let in:                        %s\n' "$letin"
if [ "$reached" = "$letin" ]; then
  echo "They match: every blocked or puzzled bot was stopped before the website."
else
  echo "They do not match. Check the logs."
fi
