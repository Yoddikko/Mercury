//
//  RSSFeedCatalog.swift
//  Mercury
//
//  Created by Codex on 01/04/26.
//

import Foundation

enum RSSFeedCatalog {
    static let allSources: [RSSFeedSource] = [
        source(
            id: "euronews-world",
            outlet: "Euronews – World News",
            region: .europeWide,
            url: "https://www.euronews.com/rss?format=mrss&level=theme&name=news",
            main: true,
            language: "en",
            tags: ["general", "world"]
        ),
        source(
            id: "dw-europe",
            outlet: "Deutsche Welle – Europe",
            region: .europeWide,
            url: "https://rss.dw.com/rdf/rss-en-eu",
            main: true,
            language: "en",
            tags: ["general", "europe"]
        ),
        source(
            id: "france24-europe",
            outlet: "France 24 – Europe",
            region: .europeWide,
            url: "https://www.france24.com/en/europe/rss",
            main: true,
            language: "en",
            tags: ["general", "europe"]
        ),
        source(
            id: "france24-europe-no-www",
            outlet: "France 24 – Europe (No WWW Alias)",
            region: .europeWide,
            url: "https://france24.com/en/europe/rss",
            language: "en",
            tags: ["general", "europe", "alias"]
        ),
        source(
            id: "euractiv-news",
            outlet: "EURACTIV – News",
            region: .europeWide,
            url: "https://www.euractiv.com/?feed=mcfeed",
            main: true,
            language: "en",
            tags: ["eu", "policy"]
        ),
        source(
            id: "euractiv-news-no-www",
            outlet: "EURACTIV – News (No WWW Alias)",
            region: .europeWide,
            url: "https://euractiv.com/?feed=mcfeed",
            language: "en",
            tags: ["eu", "policy", "alias"]
        ),
        source(
            id: "bbc-uk-frontpage",
            outlet: "BBC News – UK Front Page",
            region: .unitedKingdom,
            url: "https://feeds.bbci.co.uk/news/rss.xml",
            main: true,
            language: "en",
            tags: ["general"]
        ),
        source(
            id: "bbc-uk-politics",
            outlet: "BBC News – UK Politics",
            region: .unitedKingdom,
            url: "https://feeds.bbci.co.uk/news/politics/rss.xml",
            language: "en",
            tags: ["politics"]
        ),
        source(
            id: "bbc-world-frontpage",
            outlet: "BBC News – World Front Page",
            region: .europeWide,
            url: "https://feeds.bbci.co.uk/news/world/rss.xml",
            language: "en",
            tags: ["world"]
        ),
        source(
            id: "reuters-europe",
            outlet: "Reuters – Europe",
            region: .europeWide,
            main: true,
            language: "en",
            tags: ["wire", "subscription"],
            note: "Documented in docs as subscription/API dependent; direct RSS endpoint not specified."
        ),
        source(
            id: "eu-commission-press",
            outlet: "European Commission Press Releases",
            region: .europeWide,
            main: true,
            tags: ["official", "eu"],
            note: "Documented as official feed family; direct endpoint not specified."
        ),
        source(
            id: "eu-publications-office",
            outlet: "EU Publications Office",
            region: .europeWide,
            tags: ["official", "eu"],
            note: "Documented as RSS source; direct endpoint not specified."
        ),
        source(
            id: "euobserver",
            outlet: "EUobserver",
            region: .europeWide,
            tags: ["eu", "analysis"],
            note: "Mentioned in docs as additional outlet; RSS endpoint not specified."
        ),
        source(
            id: "politico-europe",
            outlet: "Politico Europe",
            region: .europeWide,
            tags: ["eu", "politics"],
            note: "Mentioned in docs as additional outlet; RSS endpoint not specified."
        ),
        source(
            id: "ap-news-europe",
            outlet: "AP News Europe",
            region: .europeWide,
            tags: ["wire", "europe"],
            note: "Mentioned in docs as additional outlet; RSS endpoint not specified."
        ),

        source(
            id: "orf-news",
            outlet: "ORF News",
            region: .austria,
            url: "https://rss.orf.at/news.xml",
            main: true,
            language: "de",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "orf-sports",
            outlet: "ORF Sport",
            region: .austria,
            url: "https://rss.orf.at/news.xml?sports",
            language: "de",
            tags: ["sports"]
        ),

        source(
            id: "vrt-nws",
            outlet: "VRT NWS",
            region: .belgium,
            main: true,
            language: "nl",
            tags: ["general"],
            note: "Belgium country-pick area in docs; RSS endpoint unspecified."
        ),
        source(
            id: "rtbf",
            outlet: "RTBF",
            region: .belgium,
            main: true,
            language: "fr",
            tags: ["general"],
            note: "Belgium country-pick area in docs; RSS endpoint unspecified."
        ),
        source(
            id: "le-soir",
            outlet: "Le Soir",
            region: .belgium,
            language: "fr",
            tags: ["general"],
            note: "Mentioned in docs with unverified endpoint."
        ),
        source(
            id: "de-standaard",
            outlet: "De Standaard",
            region: .belgium,
            language: "nl",
            tags: ["general"],
            note: "Mentioned in docs; endpoint not specified."
        ),
        source(
            id: "brussels-times",
            outlet: "The Brussels Times",
            region: .belgium,
            language: "en",
            tags: ["general"],
            note: "Mentioned in docs as English alternative; endpoint not specified."
        ),
        source(
            id: "lecho",
            outlet: "L'Echo",
            region: .belgium,
            language: "fr",
            tags: ["economy"],
            note: "Mentioned in docs; endpoint not specified."
        ),
        source(
            id: "de-tijd",
            outlet: "De Tijd",
            region: .belgium,
            language: "nl",
            tags: ["economy"],
            note: "Mentioned in docs; endpoint not specified."
        ),
        source(
            id: "het-laatste-nieuws",
            outlet: "Het Laatste Nieuws",
            region: .belgium,
            language: "nl",
            tags: ["general"],
            note: "Mentioned in docs; endpoint not specified."
        ),

        source(
            id: "bta-bulgaria-en",
            outlet: "BTA – Bulgaria (EN)",
            region: .bulgaria,
            url: "https://www.bta.bg/en/news/bulgaria/rss",
            main: true,
            language: "en",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "bta-world-en",
            outlet: "BTA – World (EN)",
            region: .bulgaria,
            url: "https://bta.bg/en/news/world/rss",
            language: "en",
            tags: ["world"]
        ),
        source(
            id: "bta-economy-en",
            outlet: "BTA – Economy (EN)",
            region: .bulgaria,
            url: "https://bta.bg/en/news/economy/rss",
            language: "en",
            tags: ["economy"]
        ),
        source(
            id: "bta-bulgarian",
            outlet: "BTA – България",
            region: .bulgaria,
            url: "https://bta.bg/rss",
            language: "bg",
            tags: ["general"]
        ),

        source(
            id: "hrt-vijesti",
            outlet: "HRT Vijesti",
            region: .croatia,
            url: "https://feed.hrt.hr/",
            main: true,
            language: "hr",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "hrt-sport",
            outlet: "HRT Sport",
            region: .croatia,
            url: "https://feed.hrt.hr/?feed=hrt-sport",
            language: "hr",
            tags: ["sports"]
        ),
        source(
            id: "hrt-eu",
            outlet: "HRT EU",
            region: .croatia,
            url: "https://feed.hrt.hr/?rubrika=eu",
            language: "hr",
            tags: ["eu", "politics"]
        ),
        source(
            id: "hrt-economy",
            outlet: "HRT Gospodarstvo",
            region: .croatia,
            url: "https://feed.hrt.hr/?rubrika=Gospodarstvo",
            language: "hr",
            tags: ["economy"]
        ),
        source(
            id: "hrt-science-tech",
            outlet: "HRT Znanost i Tehnologija",
            region: .croatia,
            url: "https://feed.hrt.hr/?rubrika=Znanost_i_tehnologija",
            language: "hr",
            tags: ["science", "technology"]
        ),

        source(
            id: "dr-nyheder",
            outlet: "DR Nyheder",
            region: .denmark,
            url: "https://www.dr.dk/nyheder/service/feeds/seneste",
            main: true,
            language: "da",
            tags: ["general", "country-pick"]
        ),

        source(
            id: "yle-news",
            outlet: "Yle Uutiset",
            region: .finland,
            url: "https://yle.fi/uutiset/rss/v1/news.rss",
            main: true,
            language: "fi",
            tags: ["general", "country-pick"]
        ),

        source(
            id: "lemonde-europe",
            outlet: "Le Monde – Europe (EN)",
            region: .france,
            url: "https://www.lemonde.fr/en/europe/rss_full.xml",
            main: true,
            language: "en",
            tags: ["europe", "country-pick"]
        ),

        source(
            id: "dw-deutschland",
            outlet: "Deutsche Welle – Deutschland",
            region: .germany,
            url: "https://rss.dw.com/rdf/rss-de-deutschland",
            language: "de",
            tags: ["general"]
        ),
        source(
            id: "dw-business-en",
            outlet: "Deutsche Welle – Business",
            region: .germany,
            url: "https://rss.dw.com/rdf/rss-en-bus",
            language: "en",
            tags: ["economy"]
        ),
        source(
            id: "tagesschau-rss2",
            outlet: "Tagesschau",
            region: .germany,
            url: "https://tagesschau.de/xml/rss2.xml",
            language: "de",
            tags: ["general"]
        ),

        source(
            id: "ekathimerini-feedburner",
            outlet: "eKathimerini",
            region: .greece,
            url: "https://feeds.feedburner.com/ekathimerini",
            main: true,
            language: "en",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "ekathimerini-rss",
            outlet: "Kathimerini RSS",
            region: .greece,
            url: "https://ekathimerini.com/rss",
            language: "el",
            tags: ["general"]
        ),
        source(
            id: "amna",
            outlet: "Athens News Agency (AMNA)",
            region: .greece,
            language: "en",
            tags: ["wire"],
            note: "Mentioned in docs as possible outlet; endpoint not specified."
        ),

        source(
            id: "mti-hirado",
            outlet: "MTI / Híradó",
            region: .hungary,
            url: "https://www.hirado.hu/rss/hirapi",
            main: true,
            language: "hu",
            tags: ["general", "country-pick"]
        ),

        source(
            id: "rte-news-headlines",
            outlet: "RTE News – Headlines",
            region: .ireland,
            url: "https://www.rte.ie/news/rss/news-headlines.xml",
            main: true,
            language: "en",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "rte-business",
            outlet: "RTE News – Business",
            region: .ireland,
            url: "https://www.rte.ie/news/rss/business-headlines.xml",
            language: "en",
            tags: ["economy"]
        ),
        source(
            id: "rte-gaa",
            outlet: "RTE – GAA",
            region: .ireland,
            url: "https://www.rte.ie/rss/gaa.xml",
            language: "en",
            tags: ["sports"]
        ),

        // Italy — ported from docs/rss/research/candidates-2026-06-26.json (Phase B, issue #50).
        // Outlets are listed alphabetically by name. Endpoints marked with `note` are flagged
        // for validation in Phase 3.
        source(
            id: "adnkronos-prima",
            outlet: "Adnkronos – Prima Pagina",
            region: .italy,
            url: "http://rss.adnkronos.com/RSS_PrimaPagina.xml",
            language: "it",
            tags: ["wire"],
            note: "HTTP-only endpoint; https variant to evaluate in Phase 3."
        ),
        source(
            id: "agi-cronaca",
            outlet: "AGI – Agenzia Italia (Top News)",
            region: .italy,
            url: "https://www.agi.it/feed/cronaca/rss",
            language: "it",
            tags: ["wire"],
            note: "Endpoint pattern to verify in Phase 3."
        ),
        source(
            id: "ansa-cronaca",
            outlet: "ANSA – Cronaca",
            region: .italy,
            url: "https://www.ansa.it/sito/notizie/cronaca/cronaca_rss.xml",
            language: "it",
            tags: ["general"]
        ),
        source(
            id: "ansa-cultura",
            outlet: "ANSA – Cultura",
            region: .italy,
            url: "https://www.ansa.it/sito/notizie/cultura/cultura_rss.xml",
            language: "it",
            tags: ["culture"]
        ),
        source(
            id: "ansa-economia",
            outlet: "ANSA – Economia",
            region: .italy,
            url: "https://www.ansa.it/sito/notizie/economia/economia_rss.xml",
            language: "it",
            tags: ["economy"]
        ),
        source(
            id: "ansa-english",
            outlet: "ANSA – English",
            region: .italy,
            url: "https://www.ansa.it/english/news/english_notizie.xml",
            language: "en",
            tags: ["english"]
        ),
        source(
            id: "ansa-homepage",
            outlet: "ANSA – Homepage",
            region: .italy,
            url: "https://www.ansa.it/sito/ansait_rss.xml",
            language: "it",
            tags: ["general"]
        ),
        source(
            id: "ansa-lifestyle",
            outlet: "ANSA – Lifestyle",
            region: .italy,
            url: "https://www.ansa.it/canale_lifestyle/notizie/lifestyle_rss.xml",
            language: "it",
            tags: ["lifestyle"]
        ),
        source(
            id: "ansa-mondo",
            outlet: "ANSA – Mondo",
            region: .italy,
            url: "https://www.ansa.it/sito/notizie/mondo/mondo_rss.xml",
            language: "it",
            tags: ["world"]
        ),
        source(
            id: "ansa-politica",
            outlet: "ANSA – Politica",
            region: .italy,
            url: "https://www.ansa.it/sito/notizie/politica/politica_rss.xml",
            language: "it",
            tags: ["politics"]
        ),
        source(
            id: "ansa-salute-benessere",
            outlet: "ANSA – Salute & Benessere",
            region: .italy,
            url: "https://www.ansa.it/canale_saluteebenessere/notizie/saluteebenessere_rss.xml",
            language: "it",
            tags: ["health"]
        ),
        source(
            id: "ansa-scienza",
            outlet: "ANSA – Scienza",
            region: .italy,
            url: "https://www.ansa.it/canale_scienza_tecnica/notizie/scienzaetecnica_rss.xml",
            language: "it",
            tags: ["science"]
        ),
        source(
            id: "ansa-sicilia",
            outlet: "ANSA – Sicilia (regionale)",
            region: .italy,
            url: "https://www.ansa.it/sicilia/notizie/sicilia_rss.xml",
            language: "it",
            tags: ["regional"],
            note: "Updated to canonical /sicilia/notizie/sicilia_rss.xml pattern."
        ),
        source(
            id: "ansa-sport-calcio",
            outlet: "ANSA – Sport Calcio",
            region: .italy,
            url: "https://www.ansa.it/sito/notizie/sport/calcio/calcio_rss.xml",
            language: "it",
            tags: ["sports"]
        ),
        source(
            id: "ansa-sport-generale",
            outlet: "ANSA – Sport (Generale)",
            region: .italy,
            url: "https://www.ansa.it/sito/notizie/sport/sport_rss.xml",
            language: "it",
            tags: ["sports"]
        ),
        source(
            id: "ansa-tecnologia",
            outlet: "ANSA – Tecnologia",
            region: .italy,
            url: "https://www.ansa.it/canale_tecnologia/notizie/tecnologia_rss.xml",
            language: "it",
            tags: ["technology"]
        ),
        source(
            id: "ansa-topnews",
            outlet: "ANSA – Top News",
            region: .italy,
            url: "https://www.ansa.it/sito/notizie/topnews/topnews_rss.xml",
            main: true,
            language: "it",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "corriere-cronaca",
            outlet: "Corriere della Sera – Cronaca",
            region: .italy,
            url: "https://www.corriere.it/rss/cronaca.xml",
            language: "it",
            tags: ["general"]
        ),
        source(
            id: "corriere-economia",
            outlet: "Corriere della Sera – Economia",
            region: .italy,
            url: "https://www.corriere.it/rss/economia.xml",
            language: "it",
            tags: ["economy"]
        ),
        source(
            id: "corriere-esteri",
            outlet: "Corriere della Sera – Esteri",
            region: .italy,
            url: "https://www.corriere.it/rss/esteri.xml",
            language: "it",
            tags: ["world"]
        ),
        source(
            id: "corriere-homepage",
            outlet: "Corriere della Sera – Homepage",
            region: .italy,
            url: "https://www.corriere.it/rss/homepage.xml",
            main: true,
            language: "it",
            tags: ["general"]
        ),
        source(
            id: "corriere-politica",
            outlet: "Corriere della Sera – Politica",
            region: .italy,
            url: "https://www.corriere.it/rss/politica.xml",
            language: "it",
            tags: ["politics"]
        ),
        source(
            id: "corriere-sport",
            outlet: "Corriere della Sera – Sport",
            region: .italy,
            url: "https://www.corriere.it/rss/sport.xml",
            language: "it",
            tags: ["sports"]
        ),
        source(
            id: "fanpage",
            outlet: "Fanpage",
            region: .italy,
            url: "https://www.fanpage.it/feed/",
            language: "it",
            tags: ["digital"]
        ),
        source(
            id: "gazzetta-dello-sport",
            outlet: "Gazzetta dello Sport",
            region: .italy,
            url: "https://www.gazzetta.it/rss/homepage.xml",
            language: "it",
            tags: ["sports"],
            note: "Endpoint pattern to verify in Phase 3."
        ),
        source(
            id: "guardian-italy",
            outlet: "The Guardian – Italy",
            region: .italy,
            url: "https://www.theguardian.com/world/italy/rss",
            language: "en",
            tags: ["english"]
        ),
        source(
            id: "il-fatto-quotidiano",
            outlet: "Il Fatto Quotidiano",
            region: .italy,
            url: "https://www.ilfattoquotidiano.it/feed/",
            language: "it",
            tags: ["investigative"]
        ),
        source(
            id: "il-foglio",
            outlet: "Il Foglio",
            region: .italy,
            url: "https://www.ilfoglio.it/sezioni/112/rss",
            language: "it",
            tags: ["opinion"],
            note: "Section 112 assumed to be front page; verify in Phase 3."
        ),
        source(
            id: "il-giornale",
            outlet: "Il Giornale",
            region: .italy,
            url: "https://www.ilgiornale.it/feed.xml",
            language: "it",
            tags: ["general"]
        ),
        source(
            id: "il-post",
            outlet: "Il Post",
            region: .italy,
            url: "https://www.ilpost.it/feed/",
            language: "it",
            tags: ["explainer"]
        ),
        source(
            id: "ilsole24ore-finanza",
            outlet: "Il Sole 24 Ore – Finanza",
            region: .italy,
            url: "https://www.ilsole24ore.com/rss/finanza.xml",
            language: "it",
            tags: ["finance"]
        ),
        source(
            id: "ilsole24ore-italia",
            outlet: "Il Sole 24 Ore – Italia",
            region: .italy,
            url: "https://www.ilsole24ore.com/rss/italia.xml",
            main: true,
            language: "it",
            tags: ["economy", "country-pick"]
        ),
        source(
            id: "ilsole24ore-mondo",
            outlet: "Il Sole 24 Ore – Mondo",
            region: .italy,
            url: "https://www.ilsole24ore.com/rss/mondo.xml",
            language: "it",
            tags: ["world"]
        ),
        source(
            id: "internazionale",
            outlet: "Internazionale",
            region: .italy,
            url: "https://www.internazionale.it/sitemaps/rss.xml",
            language: "it",
            tags: ["weekly"]
        ),
        source(
            id: "lastampa-copertina",
            outlet: "La Stampa – Copertina",
            region: .italy,
            url: "https://www.lastampa.it/rss/copertina.xml",
            language: "it",
            tags: ["general"]
        ),
        source(
            id: "libero-quotidiano",
            outlet: "Libero Quotidiano",
            region: .italy,
            url: "https://www.liberoquotidiano.it/rss.xml",
            language: "it",
            tags: ["general"]
        ),
        source(
            id: "linkiesta",
            outlet: "Linkiesta",
            region: .italy,
            url: "https://www.linkiesta.it/it/feed/",
            language: "it",
            tags: ["opinion"]
        ),
        source(
            id: "milan-news",
            outlet: "Milan News",
            region: .italy,
            url: "https://www.milannews.it/rss/",
            language: "it",
            tags: ["sports"]
        ),
        source(
            id: "panorama",
            outlet: "Panorama",
            region: .italy,
            url: "https://www.panorama.it/feeds/feed.rss",
            language: "it",
            tags: ["magazine"]
        ),
        source(
            id: "rai-portale-rss",
            outlet: "RAI News – Portale RSS",
            region: .italy,
            url: "https://www.rai.it/dl/portale/html/PublishingBlock-15c2c340-e282-473d-b944-661e818d667b-rss.xml",
            language: "it",
            tags: ["public-broadcaster"]
        ),
        source(
            id: "rai-radio-giornale",
            outlet: "RAI Radio – Giornale Radio",
            region: .italy,
            url: "https://www.rai.it/dl/portaleAudio/Giornale_Radio_index.rss",
            language: "it",
            tags: ["radio"]
        ),
        source(
            id: "rai-tgr-piemonte",
            outlet: "RAI TGR Piemonte",
            region: .italy,
            url: "https://www.rainews.it/tgr/rss/piemonte.xml",
            language: "it",
            tags: ["regional"]
        ),
        source(
            id: "rainews-primopiano",
            outlet: "RAI News 24 – Primo Piano",
            region: .italy,
            url: "https://www.rainews.it/rss.rss",
            main: true,
            language: "it",
            tags: ["public-broadcaster"]
        ),
        source(
            id: "repubblica-cronaca",
            outlet: "La Repubblica – Cronaca",
            region: .italy,
            url: "https://www.repubblica.it/rss/cronaca/rss2.0.xml",
            language: "it",
            tags: ["general"],
            note: "Endpoint pattern to verify in Phase 3."
        ),
        source(
            id: "repubblica-economia",
            outlet: "La Repubblica – Economia",
            region: .italy,
            url: "https://www.repubblica.it/rss/economia/rss2.0.xml",
            language: "it",
            tags: ["economy"],
            note: "Endpoint pattern to verify in Phase 3."
        ),
        source(
            id: "repubblica-esteri",
            outlet: "La Repubblica – Esteri",
            region: .italy,
            url: "https://www.repubblica.it/rss/esteri/rss2.0.xml",
            language: "it",
            tags: ["world"],
            note: "Endpoint pattern to verify in Phase 3."
        ),
        source(
            id: "repubblica-homepage",
            outlet: "La Repubblica – Homepage",
            region: .italy,
            url: "https://www.repubblica.it/rss/homepage/rss2.0.xml",
            main: true,
            language: "it",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "repubblica-politica",
            outlet: "La Repubblica – Politica",
            region: .italy,
            url: "https://www.repubblica.it/rss/politica/rss2.0.xml",
            language: "it",
            tags: ["politics"],
            note: "Endpoint pattern to verify in Phase 3."
        ),
        source(
            id: "sky-tg24-cronaca",
            outlet: "Sky TG24 – Cronaca",
            region: .italy,
            url: "https://tg24.sky.it/rss/cronaca.xml",
            language: "it",
            tags: ["general"],
            note: "Endpoint pattern to verify in Phase 3."
        ),
        source(
            id: "sky-tg24-mondo",
            outlet: "Sky TG24 – Mondo",
            region: .italy,
            url: "https://tg24.sky.it/rss/mondo.xml",
            language: "it",
            tags: ["world"],
            note: "Endpoint pattern to verify in Phase 3."
        ),
        source(
            id: "sky-tg24-politica",
            outlet: "Sky TG24 – Politica",
            region: .italy,
            url: "https://tg24.sky.it/rss/politica.xml",
            language: "it",
            tags: ["politics"],
            note: "Endpoint pattern to verify in Phase 3."
        ),
        source(
            id: "tgcom24-economia",
            outlet: "TGCOM24 – Economia",
            region: .italy,
            url: "https://www.tgcom24.mediaset.it/rss/economia.xml",
            language: "it",
            tags: ["economy"]
        ),
        source(
            id: "tgcom24-homepage",
            outlet: "TGCOM24 – Homepage",
            region: .italy,
            url: "https://www.tgcom24.mediaset.it/rss/homepage.xml",
            main: true,
            language: "it",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "tgcom24-politica",
            outlet: "TGCOM24 – Politica",
            region: .italy,
            url: "https://www.tgcom24.mediaset.it/rss/politica.xml",
            language: "it",
            tags: ["politics"]
        ),
        source(
            id: "tgcom24-spettacolo",
            outlet: "TGCOM24 – Spettacolo",
            region: .italy,
            url: "https://www.tgcom24.mediaset.it/rss/spettacolo.xml",
            language: "it",
            tags: ["entertainment"]
        ),
        source(
            id: "tgcom24-sport",
            outlet: "TGCOM24 – Sport",
            region: .italy,
            url: "https://www.tgcom24.mediaset.it/rss/sport.xml",
            language: "it",
            tags: ["sports"]
        ),
        source(
            id: "tgcom24-tgtech",
            outlet: "TGCOM24 – TGTech",
            region: .italy,
            url: "https://www.tgcom24.mediaset.it/rss/tgtech.xml",
            language: "it",
            tags: ["technology"]
        ),
        source(
            id: "the-local-italy",
            outlet: "The Local Italy",
            region: .italy,
            url: "https://feeds.thelocal.com/rss/it",
            language: "en",
            tags: ["english"]
        ),

        source(
            id: "nos-nieuwsalgemeen",
            outlet: "NOS Nieuws Algemeen",
            region: .netherlands,
            url: "https://feeds.nos.nl/nieuwsalgemeen",
            main: true,
            language: "nl",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "nos-nieuwspolitiek",
            outlet: "NOS Nieuws Politiek",
            region: .netherlands,
            url: "https://feeds.nos.nl/nieuwspolitiek",
            language: "nl",
            tags: ["politics"]
        ),
        source(
            id: "nos-sportalgemeen",
            outlet: "NOS Sport Algemeen",
            region: .netherlands,
            url: "https://feeds.nos.nl/sportalgemeen",
            language: "nl",
            tags: ["sports"]
        ),
        source(
            id: "nos-wereldnieuws",
            outlet: "NOS Wereldnieuws",
            region: .netherlands,
            url: "https://feeds.nos.nl/wereldnieuws",
            language: "nl",
            tags: ["world"]
        ),

        source(
            id: "nrk-toppsaker",
            outlet: "NRK Toppsaker",
            region: .norway,
            url: "https://www.nrk.no/toppsaker_rss.xml",
            main: true,
            language: "no",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "aftenposten",
            outlet: "Aftenposten",
            region: .norway,
            language: "no",
            tags: ["general"],
            note: "Documented in RSS list with unspecified endpoint."
        ),
        source(
            id: "vg",
            outlet: "VG",
            region: .norway,
            language: "no",
            tags: ["general"],
            note: "Documented in RSS list with unspecified endpoint."
        ),

        source(
            id: "pap-rss",
            outlet: "PAP",
            region: .poland,
            url: "https://www.pap.pl/rss",
            main: true,
            language: "pl",
            tags: ["wire", "country-pick"],
            note: "Docs mark this as hypothetical/needs verification."
        ),
        source(
            id: "tvp-info",
            outlet: "TVP Info",
            region: .poland,
            language: "pl",
            tags: ["general"],
            note: "Documented in RSS list with unspecified endpoint."
        ),
        source(
            id: "interia-news",
            outlet: "Interia News",
            region: .poland,
            language: "pl",
            tags: ["general"],
            note: "Documented in RSS list with unspecified endpoint."
        ),

        source(
            id: "rtp-noticias",
            outlet: "RTP Notícias",
            region: .portugal,
            url: "https://www.rtp.pt/noticias/index.rss",
            main: true,
            language: "pt",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "lusa",
            outlet: "Lusa",
            region: .portugal,
            language: "pt",
            tags: ["wire"],
            note: "Documented in RSS list with unspecified endpoint."
        ),
        source(
            id: "portugal-news",
            outlet: "Portugal News",
            region: .portugal,
            language: "en",
            tags: ["expat"],
            note: "Documented in RSS list with unspecified endpoint."
        ),

        source(
            id: "agerpres-rss",
            outlet: "Agerpres",
            region: .romania,
            url: "https://www.agerpres.ro/rss/",
            main: true,
            language: "ro",
            tags: ["wire", "country-pick"]
        ),
        source(
            id: "hotnews",
            outlet: "HotNews",
            region: .romania,
            language: "ro",
            tags: ["general"],
            note: "Documented in RSS list with unspecified endpoint."
        ),
        source(
            id: "digi24",
            outlet: "Digi24",
            region: .romania,
            language: "ro",
            tags: ["general"],
            note: "Documented in RSS list with unspecified endpoint."
        ),

        source(
            id: "rtve-noticias",
            outlet: "RTVE Noticias",
            region: .spain,
            url: "https://www.rtve.es/rss/noticias.xml",
            main: true,
            language: "es",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "rtve-deportes",
            outlet: "RTVE Deportes",
            region: .spain,
            url: "https://www.rtve.es/rss/deportes.xml",
            language: "es",
            tags: ["sports"]
        ),
        source(
            id: "rtve-economia",
            outlet: "RTVE Economia",
            region: .spain,
            url: "https://www.rtve.es/rss/economia.xml",
            language: "es",
            tags: ["economy"]
        ),

        source(
            id: "svt-nyheter",
            outlet: "SVT Nyheter",
            region: .sweden,
            url: "https://www.svt.se/nyheter/rss.xml",
            main: true,
            language: "sv",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "svt-sverige",
            outlet: "SVT Nyheter Sverige",
            region: .sweden,
            url: "https://www.svt.se/nyheter/sverige/rss.xml",
            language: "sv",
            tags: ["national"]
        ),
        source(
            id: "svt-varlden",
            outlet: "SVT Nyheter Världen",
            region: .sweden,
            url: "https://www.svt.se/nyheter/varlden/rss.xml",
            language: "sv",
            tags: ["world"]
        ),

        source(
            id: "srf-schweiz",
            outlet: "SRF Schweiz",
            region: .switzerland,
            url: "https://www.srf.ch/rss/schweiz.xml",
            main: true,
            language: "de",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "srf-international",
            outlet: "SRF International",
            region: .switzerland,
            url: "https://www.srf.ch/rss/international.xml",
            language: "de",
            tags: ["world"]
        ),
        source(
            id: "srf-sport-fussball",
            outlet: "SRF Sport – Fussball",
            region: .switzerland,
            url: "https://www.srf.ch/rss/sport/fussball.xml",
            language: "de",
            tags: ["sports"]
        ),
        source(
            id: "rts-switzerland",
            outlet: "RTS (French Switzerland)",
            region: .switzerland,
            language: "fr",
            tags: ["general"],
            note: "Documented in RSS list with unspecified endpoint."
        ),
        source(
            id: "rsi-switzerland",
            outlet: "RSI (Italian Switzerland)",
            region: .switzerland,
            language: "it",
            tags: ["general"],
            note: "Documented in RSS list with unspecified endpoint."
        ),

        source(
            id: "guardian-uk",
            outlet: "The Guardian",
            region: .unitedKingdom,
            language: "en",
            tags: ["general"],
            note: "Mentioned in docs as additional UK outlet; endpoint not specified."
        ),
        source(
            id: "cnn-international",
            outlet: "CNN International",
            region: .unitedKingdom,
            language: "en",
            tags: ["world"],
            note: "Mentioned in docs as additional outlet; endpoint not specified."
        )
    ]

    static var availableRegions: [RSSFeedRegion] {
        RSSFeedRegion.allCases.filter { region in
            allSources.contains { $0.region == region }
        }
    }

    static func sources(
        for groupMode: RSSFeedGroupMode,
        region: RSSFeedRegion?
    ) -> [RSSFeedSource] {
        let filtered: [RSSFeedSource]
        switch groupMode {
        case .allOutlets:
            filtered = allSources
        case .mainOutlets:
            filtered = allSources.filter(\.isMainOutlet)
        case .byRegion:
            guard let region else { return [] }
            filtered = allSources.filter { $0.region == region }
        }

        return filtered.sorted { lhs, rhs in
            if lhs.region.rawValue != rhs.region.rawValue {
                return lhs.region.rawValue < rhs.region.rawValue
            }
            return lhs.outletName.localizedCaseInsensitiveCompare(rhs.outletName) == .orderedAscending
        }
    }

    private static func source(
        id: String,
        outlet: String,
        region: RSSFeedRegion,
        url: String? = nil,
        main: Bool = false,
        language: String? = nil,
        tags: [String] = [],
        note: String? = nil
    ) -> RSSFeedSource {
        RSSFeedSource(
            id: id,
            outletName: outlet,
            region: region,
            feedURLString: url,
            isMainOutlet: main,
            languageCode: language,
            tags: tags,
            note: note
        )
    }
}
