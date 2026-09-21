#!/usr/bin/env bash
# Live, readable view of what Anubis decides for each visitor.
# Run it in its own terminal window during the demo:   ./demo/watch-log.sh
# Press Ctrl+C to stop.
#
# Anubis only logs when it acts: blocking a bot or handing out a puzzle.
# Visitors that are simply let in (git, the JSON API, plain curl) do not
# appear here. That is normal.
cd "$(dirname "$0")/.." || exit 1
command -v jq >/dev/null || { echo "This needs jq. Install it with: brew install jq"; exit 1; }

echo "Watching Anubis. Visit http://localhost:8888 and each decision shows up here."
echo

docker compose logs -f --since 0s --no-log-prefix anubis 2>/dev/null |
jq -R -r --unbuffered '
  fromjson?
  | select(.msg == "explicit deny" or .msg == "new challenge issued")
  | select((.path // "") | test("\\.map$") | not)          # skip DevTools debug files
  | (.user_agent // "") as $ua
  | (["GPTBot","ClaudeBot","ChatGPT-User","PerplexityBot","Bytespider","CCBot",
      "HeadlessChrome","Googlebot","bingbot","Firefox","Chrome","Safari","curl"]
     | map(select(. as $n | $ua | test($n; "i"))) | first) // ($ua[0:24]) as $who
  | (.time[11:19]) as $t
  | if .msg == "explicit deny" then
      "\($t)  BLOCKED   \(($who + "                ")[0:16]) \((.path + "          ")[0:10]) rule: \(.check_result.name)"
    else
      # points -> puzzle size, same numbers as the thresholds in botPolicies.yaml
      (if .weight >= 30 then "hard puzzle (difficulty 5)" else "easy puzzle (difficulty 2)" end) as $p
      | "\($t)  PUZZLE    \(($who + "                ")[0:16]) \((.path + "          ")[0:10]) weight \(.weight), \($p)"
    end
'
