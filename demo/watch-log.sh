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
  # Work out a short name for the visitor from its name tag (User-Agent).
  # 1. known bots, most specific first
  # 2. the word after "compatible;" (how many bots name themselves)
  # 3. the browser name
  # 4. the first word of the name tag, e.g. "curl" from "curl/8.7.1"
  | ([["GPTBot","GPTBot"], ["ChatGPT-User","ChatGPT-User"], ["OAI-SearchBot","OAI-SearchBot"],
      ["ClaudeBot","ClaudeBot"], ["Claude-User","Claude-User"], ["Claude-SearchBot","Claude-SearchBot"],
      ["PerplexityBot","PerplexityBot"], ["Perplexity-User","Perplexity-User"],
      ["Bytespider","Bytespider"], ["meta-externalagent","meta-externalagent"],
      ["Amazonbot","Amazonbot"], ["CCBot","CCBot"], ["cohere-ai","cohere-ai"], ["Diffbot","Diffbot"],
      ["Scrapy","Scrapy"], ["HeadlessChrome","HeadlessChrome"], ["Lightpanda","Lightpanda"],
      ["Googlebot","Googlebot"], ["bingbot","bingbot"], ["DuckDuckBot","DuckDuckBot"],
      ["Applebot","Applebot"], ["YandexBot","YandexBot"], ["Baiduspider","Baiduspider"],
      ["AhrefsBot","AhrefsBot"], ["SemrushBot","SemrushBot"],
      ["facebookexternalhit","facebookexternalhit"], ["Twitterbot","Twitterbot"],
      ["Slackbot","Slackbot"], ["Discordbot","Discordbot"],
      ["python-requests","python-requests"], ["Go-http-client","Go-http-client"],
      ["node-fetch","node-fetch"], ["Wget","^Wget/"], ["curl","^curl/"], ["git","^git/"]]) as $known
  | ( first($known[] | select(.[1] as $re | $ua | test($re; "i")) | .[0])
      // ($ua | capture("compatible; ?(?<n>[^/;) ]+)")? | .n)
      // (if   ($ua | test("Firefox/")) then "Firefox"
          elif ($ua | test("Edg/"))     then "Edge"
          elif ($ua | test("Chrome/"))  then "Chrome"
          elif ($ua | test("Safari/"))  then "Safari"
          else empty end)
      // ($ua | capture("^(?<n>[^/ ]+)")? | .n)
      // "(no name tag)" ) as $who
  | (.time[11:19]) as $t
  | if .msg == "explicit deny" then
      "\($t)  BLOCKED   \(($who + "                    ")[0:20]) \((.path + "          ")[0:10]) rule: \(.check_result.name)"
    else
      # points -> puzzle size, same numbers as the thresholds in botPolicies.yaml
      (if .weight >= 40 then "hardest puzzle (difficulty 6)" elif .weight >= 30 then "hard puzzle (difficulty 5)" else "easy puzzle (difficulty 2)" end) as $p
      | "\($t)  PUZZLE    \(($who + "                    ")[0:20]) \((.path + "          ")[0:10]) weight \(.weight), \($p)"
    end
'
