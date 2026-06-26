# Americas News RSS Feeds (AMERICAS_RSS.md) – 2026-06-26

Phase B of the RSS overhaul (issue #50) introduced two new regions in the
Americas to the Mercury catalog: **United States** and **Brazil**. The full
candidate list is captured in
[`research/candidates-2026-06-26.json`](research/candidates-2026-06-26.json)
and ported into `Mercury/Mercury/Data/Remote/RSS/RSSFeedCatalog.swift`.

Validation diagnostics on each endpoint are deferred to Phase 3; entries
flagged with `note` in the catalog are URL patterns inherited from public
directories that need a live check before being treated as authoritative.

## United States (15 outlets)

| Outlet | Feed URL | Category |
| --- | --- | --- |
| AP News – Top Headlines | `https://news.google.com/rss/search?q=site%3Aapnews.com+when%3A1d&hl=en-US&gl=US&ceid=US:en` | Wire (Google News proxy) |
| CNBC – US Top News | `https://www.cnbc.com/id/100003114/device/rss/rss.html` | Business broadcast |
| CNN – Top Stories | `http://rss.cnn.com/rss/edition.rss` | Broadcast news |
| Fox News – Latest | `https://moxie.foxnews.com/google-publisher/latest.xml` | Broadcast news |
| HuffPost – World News | `https://www.huffpost.com/section/world-news/feed` | Digital native |
| LA Times – World & Nation | `https://www.latimes.com/world-nation/rss2.0.xml` | Regional broadsheet |
| NPR – Business | `https://feeds.npr.org/1006/rss.xml` | Public radio (business) |
| **NPR – Top Stories** (country-pick) | `https://feeds.npr.org/1001/rss.xml` | Public radio |
| NPR – World | `https://feeds.npr.org/1004/rss.xml` | Public radio (world) |
| **NYT – Top Stories** (country-pick) | `https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml` | National broadsheet |
| NYT – World | `https://rss.nytimes.com/services/xml/rss/nyt/World.xml` | National broadsheet (world) |
| Politico – Playbook | `https://rss.politico.com/playbook.xml` | Political newsletter |
| Reuters – Top News (legacy) | `https://feeds.reuters.com/reuters/topNews` | Wire (likely dead) |
| Washington Post – World | `http://feeds.washingtonpost.com/rss/world` | National broadsheet (world) |
| WSJ – World News | `https://feeds.a.dj.com/rss/RSSWorldNews.xml` | Business daily (world) |

**Sourcing notes**

- AP retired its public RSS in 2023; a Google News query is used as a
  short-term proxy. Phase 3 may swap to a partner endpoint or feed reader.
- Reuters' legacy Feedburner endpoints have been intermittently dead since
  2022. The catalog keeps `reuters-top-legacy` so Phase 3 diagnostics can
  flag it explicitly.
- Fox News migrated its Feedburner endpoint to `moxie.foxnews.com` in
  2024; the catalog uses the new location.

## Brazil (9 outlets)

| Outlet | Feed URL | Category |
| --- | --- | --- |
| Agência Brasil | `https://agenciabrasil.ebc.com.br/rss.xml` | Public wire |
| Brasil Wire (EN) | `https://www.brasilwire.com/feed/` | English-language analysis |
| **Folha de S.Paulo – Em cima da hora** (country-pick) | `https://feeds.folha.uol.com.br/emcimadahora/rss091.xml` | Broadsheet daily |
| G1 – Globo | `https://g1.globo.com/rss/g1/` | Globo portal |
| Jornal de Brasília | `https://jornaldebrasilia.com.br/feed/` | Regional daily (capital) |
| Portal EBC | `https://www.ebc.com.br/rss/feed.xml` | Public broadcaster portal |
| R7 – Notícias | `https://noticias.r7.com/feed.xml` | Record TV portal |
| The Rio Times (EN) | `https://riotimesonline.com/feed/` | English-language |
| UOL | `https://rss.home.uol.com.br/index.xml` | Digital portal |

**Sourcing notes**

- Most entries were harvested from the
  [plenaryapp/awesome-rss-feeds Brazil OPML](https://github.com/plenaryapp/awesome-rss-feeds).
- Agência Brasil and G1 endpoints follow documented patterns but were not
  hit live; Phase 3 will confirm.

## Mercury MVP recommendation

For the immediate MVP launch in the Americas, prioritise the
**country-pick** entries (`NPR – Top Stories`, `NYT – Top Stories`,
`Folha de S.Paulo – Em cima da hora`). They are public, high-frequency,
and require no API credentials. Other entries should be enabled as Phase 3
validation marks them stable.

## Legal & best practices

Same baseline as `EUROPE_RSS.md`: respect publisher terms, follow
`robots.txt`, only render headline + excerpt with attribution, throttle
fetches (15–60 minute cadence per outlet), prefer conditional GETs.
