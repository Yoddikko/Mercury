# Asia News RSS Feeds (ASIA_RSS.md) – 2026-06-26

Phase B of the RSS overhaul (issue #50) introduced **Japan** as the first
Asian region in the Mercury catalog. The full candidate list is captured
in [`research/candidates-2026-06-26.json`](research/candidates-2026-06-26.json)
and ported into `Mercury/Mercury/Data/Remote/RSS/RSSFeedCatalog.swift`
under the `// MARK: - Japan` section.

Validation diagnostics on each endpoint are deferred to Phase 3; entries
flagged with `note` in the catalog are URL patterns inherited from public
directories that need a live check before being treated as authoritative.

## Japan (8 outlets)

| Outlet | Feed URL | Language | Category |
| --- | --- | --- | --- |
| Asahi Shimbun – Headlines | `http://rss.asahi.com/rss/asahi/newsheadlines.rdf` | ja | Broadsheet daily |
| **Japan Times – Top Stories** (country-pick) | `https://www.japantimes.co.jp/feed/topstories/` | en | English-language daily |
| Japan Today | `https://japantoday.com/feed` | en | English-language digital |
| Kyodo News+ (EN) | `https://english.kyodonews.net/rss/all.xml` | en | Wire service (English) |
| Livedoor News – Top | `https://news.livedoor.com/topics/rss/top.xml` | ja | Digital portal |
| The Mainichi (EN) | `https://mainichi.jp/rss/etc/mailnews.rss` | en | Broadsheet (English) |
| News On Japan | `https://www.newsonjapan.com/rss/top.xml` | en | English digital |
| NHK World – Top Stories (EN) | `https://www3.nhk.or.jp/nhkworld/en/news/feeds/rss/news-en.xml` | en | Public broadcaster (English) |

**Sourcing notes**

- All entries were harvested from the
  [plenaryapp/awesome-rss-feeds Japan OPML](https://github.com/plenaryapp/awesome-rss-feeds)
  except the Mainichi and NHK endpoints, which follow documented patterns
  from each outlet's developer guidance.
- Asahi Shimbun's primary RSS endpoint is HTTP-only; the catalog keeps
  the documented URL and Phase 3 will explore HTTPS alternatives.

## Mercury MVP recommendation

For the immediate MVP launch in Asia, prioritise the English-language
country-pick (`Japan Times – Top Stories`) plus the public broadcaster
(`NHK World – Top Stories (EN)`). Both are open, high-frequency, and ship
clean RSS payloads. Japanese-language outlets can be enabled once
locale-aware UI polish lands.

## Legal & best practices

Same baseline as `EUROPE_RSS.md`: respect publisher terms, follow
`robots.txt`, only render headline + excerpt with attribution, throttle
fetches (15–60 minute cadence per outlet), prefer conditional GETs.
