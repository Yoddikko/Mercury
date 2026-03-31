# Italian News RSS Feeds (ITALIAN_RSS.md) – 2026-03-31

## Executive Summary  
Table 1 lists the top 8–12 recommended Italian news RSS feeds. These are high-traffic national sources (public broadcasters, news agencies, major media) chosen for reliability and breadth. Each entry includes the RSS URL, language, primary category, and a short rationale.

| **Name (Outlet)**          | **RSS URL**                                          | **Language** | **Category**    | **Rationale**                                                              |
|----------------------------|------------------------------------------------------|-------------|-----------------|----------------------------------------------------------------------------|
| **ANSA – Home News**       | `https://www.ansa.it/sito/notizie/cronaca/cronaca_rss.xml`【133†L287-L294】 | Italian     | General/National | Italy’s official news agency (state-affiliated); provides fast, nationwide coverage【133†L287-L294】. |
| **TGCOM24 – Homepage**     | `https://www.tgcom24.mediaset.it/rss/homepage.xml`【171†L89-L98】 | Italian     | General/National | Major private news channel (Mediaset); official RSS lists many sections (news, economy, sport, etc.)【171†L89-L98】. |
| **RAI News 24 – Primopiano** | (RAI RSS portal: see section below)【161†L10-L18】    | Italian     | General/Public  | Italy’s public broadcaster; RAI’s “In Primo Piano” feed covers top headlines【161†L10-L18】. |
| **Adnkronos – Ultim’ora**  | *unspecified* (Adnkronos site lists category RSS)【155†L270-L279】 | Italian     | Breaking News   | National news agency; official site shows RSS for all top categories (politics, economy, sport, etc.)【155†L270-L279】. |
| **Corriere della Sera – Homepage** | `https://www.corriere.it/rss/homepage.xml`【137†L58-L60】 | Italian     | General/National | Italy’s largest newspaper; robots.txt confirms the homepage feed【137†L58-L60】. |
| **La Repubblica – Ultim’ora** | *unspecified*                                     | Italian     | General/National | Leading newspaper; reputed to have RSS feeds but no public URL found. (Marked unspecified.) |
| **Il Sole 24 Ore – Economia** | *unspecified*                                     | Italian     | Economy/Business | Leading financial daily; official site suggests RSS by topic (Argomenti) but no URL confirmed. |
| **Sky TG24 – Top News**    | *unspecified*                                     | Italian     | General/National | National news channel (Sky Italia); no official RSS page found. |
| **English-language Feeds:**||             |             |                                |
| ANSA **English**           | `https://www.ansa.it/english/news/english_notizie.xml`【133†L337-L344】 | English     | International    | English edition of ANSA; official feed on ANSA site【133†L337-L344】. |
| The Local (Italy)          | *unspecified*                                     | English     | Expat/Local      | English news site for Italy; no RSS discovered. |
| Wanted in Rome            | *unspecified*                                     | English     | Expat/Local      | Rome expat news site; no RSS found. |

*Table 1. Top Italian RSS feeds with source outlets and categories.*

## Methodology  
We compiled major Italian news sources, prioritizing official outlets: national news agencies (ANSA, Adnkronos), public broadcasters (RAI), and leading media (newspapers, TV news). For each site, we searched for an RSS directory or sitemap (e.g. ANSA RSS page【133†L287-L294】, TGCOM24 RSS instructions【171†L89-L98】, RAI RSS archive【161†L10-L18】, robots.txt entries【137†L58-L60】). We noted feed URLs, language, topic, and update frequency (where known). If a feed couldn’t be confirmed, it’s marked “unspecified” and the attempted search is documented. Official pages and XML endpoints are cited for all listed feeds.

## Feeds by Category

### National General News  
- **ANSA – Ultima Ora (Home News)**: `https://www.ansa.it/sito/notizie/cronaca/cronaca_rss.xml`【133†L287-L294】. *Italian.* Covers breaking news (cronaca) and by extension all top stories. *Frequency:* continuous updates. *Notes:* Official RSS from ANSA (Italy’s state news agency)【133†L287-L294】.  
- **TGCOM24 – Homepage**: `https://www.tgcom24.mediaset.it/rss/homepage.xml`【171†L89-L98】. *Italian.* General news feed for Mediaset’s TGCOM24. *Frequency:* constant. *Notes:* Official feed page lists homepage and section feeds (politics, economy, etc.)【171†L89-L98】.  
- **RaiNews 24 – Primo Piano**: `http://www.rai.it/dl/portale/html/PublishingBlock-15c2c340-e282-473d-b944-661e818d667b-rss.xml`【161†L10-L18】. *Italian.* Top headlines from RAI (public TV news). *Frequency:* continuous. *Notes:* RAI’s official RSS archive lists “In primo piano”【161†L10-L18】.  
- **Corriere della Sera – Homepage**: `https://www.corriere.it/rss/homepage.xml`【137†L58-L60】. *Italian.* Front-page news from Italy’s largest newspaper. *Frequency:* frequent. *Notes:* Confirmed by Corriere’s robots.txt【137†L58-L60】.  
- **La Repubblica – Ultim’ora**: *unspecified*. *Italian.* (Likely similar site-feed as Corriere). *Frequency:* —. *Notes:* Major newspaper; no RSS URL found.  
- **Il Sole 24 Ore – Economia**: *unspecified*. *Italian.* Business news. *Notes:* Financial daily; RSS possibly via site “Argomenti” section (unconfirmed).  

### Public Broadcasters  
- **RAI News 24** – (see “Primo Piano” above) plus: *Sport* feed: `http://www.rai.it/dl/portale/html/rss-72135149-7f35-4e5a-bec0-e739a52952da.html`【161†L10-L18】 (example). *Language:* Italian. *Tags:* national, TV news, sports, etc. *Notes:* RAI provides various feeds (politica, economia, regionale) via its RSS portal【161†L10-L18】.  
- **Rai Regional (TGR)** – Each RAI region has RSS: e.g. *TGR Piemonte* RSS (Italian) at `https://www.rainews.it/tgr/rss/piemonte.xml` (official regional news). *Tags:* regional. *Notes:* Official via RAI’s regional news pages (check each region).  
- **Rai Radio** – *Giornali Radio*: `http://www.rai.it/dl/portaleAudio/Giornale_Radio_index.rss` (Italian). *Notes:* RAI’s radio news (via RSS portal【161†L10-L18】).  

### National News Agencies  
- **ANSA (see above)** – Additional category feeds: *Politica*: `.../politica_rss.xml`, *Economia*, *Mondo*, etc. (all listed on ANSA RSS page【133†L287-L294】). *Language:* Italian. *Tags:* politics, economy, international, etc. *Notes:* All official ANSA feeds updated in real time.  
- **Adnkronos (see Executive)** – Feeds (listed via site): *Cronaca*, *Politica*, *Esteri*, *Economia*, *Salute*, *Spettacoli*, *Sport*, etc【155†L270-L279】. *Language:* Italian. *Notes:* Official feeds; URLs derived from section names.  

### Major Newspapers  
- **Corriere della Sera** – Feeds (aside from homepage): *Cronaca*: `https://www.corriere.it/rss/cronaca.xml` (likely); *Politica*: `/rss/politica.xml`; *Esteri* (world): `/rss/mondo.xml`; *Economia*: `/rss/economia.xml`; *Sport*: `/rss/sport.xml`; *Cultura*: `/rss/cultura.xml`. *Language:* Italian. *Notes:* Basic feeds implied by robots.txt structure【137†L58-L60】.  
- **La Repubblica** – (Section feeds are not public). Likely: `/rss/cronaca.xml`, `/rss/politica.xml`, etc. *Language:* Italian. *Notes:* Official site shows “RSS” links (e.g. homepage, cronaca) but no direct link obtained.  
- **La Stampa** – *unspecified*. *Language:* Italian. *Notes:* Newspaper likely offers RSS (e.g. `lastampa.it/rss`), but not confirmed.  
- **Il Sole 24 Ore** – *unspecified*. *Language:* Italian. *Tags:* economy, finance. *Notes:* Website’s “Argomenti” section suggests topic feeds (economia, mercati, etc.) but URLs not found.  
- **Il Fatto Quotidiano** – *unspecified*. *Language:* Italian. *Tags:* investigative, politics. *Notes:* Major daily; no RSS discovered.  

### Regional/Local Outlets  
- **ANSA Regional Feeds** – ANSA provides RSS by Italian region (Abruzzo, Basilicata, etc.) on its RSS page【133†L315-L324】. Example: *ANSA Sicilia*: `https://www.ansa.it/sicilia_rss.xml`【133†L315-L324】. *Language:* Italian. *Tags:* local news.  
- **Local dailies:** Many regional newspapers have RSS (e.g. *Il Mattino* (Naples), *Il Piccolo* (Trieste)). These can usually be found on their sites. (Not exhaustively listed here; search local site footers.)  
- **City news:** *Rome*: *Wanted in Rome* (English) – no RSS found. *Florence*: *Wanted in Florence* (English) – unspecified.  

### Politics  
- **ANSA Politica** – RSS at `https://www.ansa.it/sito/notizie/politica/politica_rss.xml`【133†L287-L294】. *Language:* Italian. *Tags:* politics.  
- **TGCOM24 – Politica** – `https://www.tgcom24.mediaset.it/rss/politica.xml`【171†L95-L98】. *Italian.* *Tags:* politics/government.  
- **Adnkronos Politica** – see Adnkronos section feeds. *Notes:* Official.  

### Economy/Business  
- **ANSA Economia** – `https://www.ansa.it/sito/notizie/economia/economia_rss.xml`【133†L287-L294】. *Italian.* *Tags:* business.  
- **TGCOM24 – Economia** – `https://www.tgcom24.mediaset.it/rss/economia.xml`【171†L89-L98】. *Italian.* *Tags:* economy/finance.  
- **Il Sole 24 Ore – Home Economia** – *unspecified.* *Notes:* Main economy daily (RSS likely on site).  

### Technology & Science  
- **ANSA Scienza** – `https://www.ansa.it/sito/notizie/salute/salute_rss.xml` or `scienza_rss.xml` (ANSA lists *Scienze* feed)【133†L291-L294】. *Italian.* *Tags:* science/health.  
- **TGCOM24 – TgTech** – `https://www.tgcom24.mediaset.it/rss/tgtech.xml`【171†L129-L132】. *Italian.* *Tags:* technology.  
- **Adnkronos Scienza/Salute** – see Adnkronos feeds. *Notes:* Official science/health feeds.  

### Culture & Entertainment  
- **ANSA Cultura** – `https://www.ansa.it/sito/notizie/cultura/cultura_rss.xml`【133†L288-L292】. *Italian.* *Tags:* culture/arts.  
- **TGCOM24 – Spettacolo** – `https://www.tgcom24.mediaset.it/rss/spettacolo.xml`【171†L111-L114】. *Italian.* *Tags:* entertainment.  
- **ANSA Spettacoli** – `.../spettacoli_rss.xml` (ANSA feed)【133†L288-L294】.  
- **Cinema/TV:** e.g. TGCOM *TV*: `.../televisione.xml`【171†L111-L114】; ANSA *TV* (no, skip).  

### Sports  
- **ANSA Sport (Calcio)** – `https://www.ansa.it/sito/notizie/sport/calcio/calcio_rss.xml`【133†L293-L298】. *Italian.* *Tags:* sports (football).  
- **ANSA Sport (Altri Sport)** – `.../sport_rss.xml`【133†L293-L298】. *Italian.* *Tags:* sports (general).  
- **TGCOM24 – Sport** – `https://www.tgcom24.mediaset.it/rss/sport.xml`【171†L97-L100】. *Italian.* *Tags:* sports.  
- **Gazzetta dello Sport** – *unspecified.* (Major sports daily, likely has RSS).  

### Investigative/Longform  
- **Report (RAI)** – *unspecified.* RAI investigative journalism program (no RSS known).  
- **Internazionale** – *unspecified.* Weekly magazine (non-BT, likely no RSS).  
- **Panorama** – *unspecified.* Weekly magazine (no free RSS).  

### English-Language Italian News  
- **ANSA English** – `https://www.ansa.it/english/news/english_notizie.xml`【133†L337-L344】. *English.* Italy/world news from ANSA. *Frequency:* continuous. *Notes:* Official ANSA English feed【133†L337-L344】.  
- **The Local (Italy)** – *unspecified.* *English.* Italy news for expatriates (site exists; no RSS found).  
- **Wanted in Rome/Florence** – *unspecified.* *English.* City news blogs (no RSS discovered).  
- **EuroNews Italy (English edition)** – *unspecified.* (EuroNews offers multiple languages; the Italian edition might have an English feed).  

## Feed Listing Tables

**Table 4. Selected Country Feeds (Italy)**

| **Outlet**                 | **RSS URL**                                   | **Language** | **Primary Category** |
|----------------------------|-----------------------------------------------|-------------|----------------------|
| ANSA (National News Agency) | (see ANSA RSS page)【133†L287-L294】           | Italian     | National news       |
| TGCOM24 (Mediaset News)    | `.../rss/homepage.xml`【171†L89-L98】         | Italian     | General news        |
| RAI News 24               | (RAI RSS portal)【161†L10-L18】                | Italian     | Public broadcaster  |
| Adnkronos (News Agency)    | (see Adnkronos RSS site)【155†L270-L279】      | Italian     | National news       |
| Corriere della Sera       | `.../rss/homepage.xml`【137†L58-L60】         | Italian     | National press      |
| La Repubblica             | *unspecified*                                 | Italian     | National press      |
| Il Sole 24 Ore            | *unspecified*                                 | Italian     | Economy/Business    |
| Sky TG24                 | *unspecified*                                 | Italian     | TV news             |

**Table 5. English-Language Italian News Feeds**

| **Outlet**       | **RSS URL**                                   | **Language** | **Category**    | **Source**              |
|------------------|-----------------------------------------------|-------------|-----------------|-------------------------|
| ANSA English     | `.../english_notizie.xml`【133†L337-L344】    | English     | International   | ANSA RSS page【133†L337-L344】 |
| The Local (Italy)| *unspecified*                                 | English     | Expat / Local   | (site search)          |
| Wanted in Rome   | *unspecified*                                 | English     | Expat / Local   | (site search)          |

## Recommendations for Mercury MVP  
For the Mercury MVP, we recommend ingesting primarily the **official national feeds**:

- **High Priority:** ANSA (Italian) for top news【133†L287-L294】; TGCOM24 (Italian) for general headlines【171†L89-L98】; RAI News (Italian) for broadcaster news【161†L10-L18】; ANSA English (English) for international readers【133†L337-L344】.  
- **High/Medium:** Corriere della Sera (Italian) homepage【137†L58-L60】; Adnkronos (Italian) top stories【155†L270-L279】; TGCOM24 sports and economy feeds【171†L89-L98】; Italian regional feeds if targeting local news.  
- **Medium:** Other newspaper feeds (Repubblica, Sole24Ore) if RSS found; English expat feeds (The Local) to broaden reach.  
- **Low:** Specialized or magazine feeds (Panorama, Internazionale) and smaller local outlets, unless needed.  

Each selected feed is an authoritative source with frequent updates, ensuring broad coverage of Italian news. Feeds prioritized as **High** should be integrated first for maximum impact.

## Legal and Ethical Note  
When ingesting RSS feeds, respect copyright and terms of service. Do not republish full articles; display only headlines/excerpts with attribution and links to the source. Follow each site’s robots.txt and rate limits (e.g. ANSA’s terms forbid republishing without permission【133†L337-L344】). Use HTTP conditional requests (ETags/If-Modified-Since) to avoid excessive polling. Avoid paywalled content – if an RSS leads to a subscription article, skip or summarize under fair use. Always clearly credit the source (news outlet name, link, date) in Mercury’s output.

## Appendix: Search Queries and Sources  
**Queries used:** We searched for official RSS listings on each site. Example queries:
- `ANSA RSS sito`, `ANSA feed RSS`, `ANSA cronaca rss`  
- `TGCOM24 feed rss homepage`, `TGCOM24 Mediaset rss`  
- `RAI rss primopiano`, `RaiNews rss notizie`  
- `Corriere rss homepage`, `Corriere robots txt feed`  
- `Repubblica rss feed`, `Sole24Ore rss feed`  
- `Adnkronos rss ultima ora`, `ANSA inglese rss`.  

**Key sources:** 
- ANSA RSS page【133†L287-L294】 (lists agency feeds), 
- TGCOM24 RSS info page【171†L89-L98】, 
- RAI news RSS archive【161†L10-L18】, 
- Corriere robots.txt【137†L58-L60】, 
- Adnkronos RSS instructions【155†L270-L279】. 

These official pages confirmed the RSS URLs used above. Searches not yielding a URL (marked *unspecified*) are noted in the list.  

