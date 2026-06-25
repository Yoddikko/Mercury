//
//  AIPlaygroundSampleArticles.swift
//  Mercury
//
//  Created by Codex on 25/06/26.
//

#if DEBUG

import Foundation

/// Curated dummy article payloads used by the Developer Playground when
/// exercising AI features in isolation. These fixtures are intentionally
/// well-formed (clear topic, multi-paragraph body, named entities) so that
/// summarization, categorization, and tag generation can be evaluated
/// against realistic but deterministic inputs.
enum AIPlaygroundSampleArticles {
    struct Sample: Identifiable, Hashable, Sendable {
        let id: String
        let titleKey: String
        let titleFallback: String
        let descriptionKey: String
        let descriptionFallback: String
        let body: String
    }

    static let all: [Sample] = [
        Sample(
            id: "tech_chip",
            titleKey: "developer.playground.ai_features.sample.tech_chip.title",
            titleFallback: "Aurora unveils 2 nm AI chip with on-device large model support",
            descriptionKey: "developer.playground.ai_features.sample.tech_chip.description",
            descriptionFallback: "Long-form technology article useful for summarization, categorization, and tag generation.",
            body: """
            Aurora Semiconductor announced on Tuesday a new 2 nanometer system-on-chip designed specifically for on-device artificial intelligence workloads. The company claims its Helix architecture can run a 30 billion parameter language model entirely offline on a smartphone, with sustained performance of roughly 45 tokens per second and a peak power draw of 6 watts.

            During a press briefing at its Cupertino headquarters, chief technology officer Dr. Maya Iyer said the chip combines a 16-core CPU, a 40-core GPU, and a dedicated neural engine with 256 megabytes of on-package SRAM. Iyer emphasized that the SRAM bandwidth, not raw FLOPS, was the decisive factor for transformer inference: "Memory locality is the difference between a real assistant and a slideshow," she said.

            Aurora also presented benchmarks comparing Helix to the previous generation Photon chip and to competing parts from Halcyon and Brightline. In a translation task using a 7B parameter model, Helix completed 200 sentences in 11 seconds, against 19 seconds for Photon and 24 seconds for Halcyon's HX-3. Battery drain during continuous inference was 9 percent per hour on a reference phone.

            The first device shipping with Helix will be Aurora's own Lumen X smartphone, due in October. Three partner manufacturers, including a leading South Korean automaker, have signed multi-year licensing deals for automotive and industrial variants. Analysts at Northridge Research estimate Aurora's data center division could capture eight percent of the inference accelerator market by 2027 if Helix-derived server parts launch on schedule.

            Privacy advocates welcomed the announcement, noting that running models on-device reduces the volume of personal data sent to remote servers. The Electronic Frontier Foundation called the launch "a meaningful step toward keeping AI inference under the user's control," while cautioning that hardware alone does not guarantee privacy if applications still upload prompts.
            """
        ),
        Sample(
            id: "business_merger",
            titleKey: "developer.playground.ai_features.sample.business_merger.title",
            titleFallback: "Northwind and Vesta agree on 14 billion dollar merger to reshape grocery logistics",
            descriptionKey: "developer.playground.ai_features.sample.business_merger.description",
            descriptionFallback: "Business and economy article for testing categorization and tag extraction.",
            body: """
            Northwind Logistics and Vesta Foods announced on Monday that their boards have unanimously approved an all-stock merger valued at approximately 14 billion dollars. The combined company, to be renamed Northwind Vesta, will become the largest cold-chain grocery distributor in North America, operating 220 facilities and a fleet of 11,000 refrigerated vehicles.

            Under the agreement, Vesta shareholders will receive 1.78 shares of Northwind for each Vesta share, representing a 22 percent premium over Vesta's closing price on Friday. The transaction is expected to close in the second quarter of next year, subject to regulatory approval and a customary shareholder vote.

            Chief executive officer Lin Park, who will lead the merged entity, framed the deal as a response to persistent inflation in food distribution and to growing pressure from online grocery competitors. "Scale lets us hold prices stable for retailers without compressing margins for farmers," Park said on an investor call. The company projects 480 million dollars in annual cost synergies by year three, primarily from route consolidation and shared procurement of fuel and packaging.

            Analysts at Crescent Capital said the deal was "logical but not without antitrust risk," highlighting that the combined entity would control roughly 28 percent of refrigerated freight capacity east of the Mississippi. The Federal Trade Commission has not yet commented, although a spokesperson confirmed the agency will conduct a standard pre-merger review.

            Union leaders welcomed early commitments by both companies to honor existing collective bargaining agreements and to keep all unionized distribution centers open for at least three years after closing. Independent analysts cautioned, however, that the longer-term impact on warehouse employment will depend on how aggressively the combined company adopts robotics in its sorting facilities.
            """
        ),
        Sample(
            id: "science_climate",
            titleKey: "developer.playground.ai_features.sample.science_climate.title",
            titleFallback: "Ocean heat content reaches new record as researchers refine 2026 climate outlook",
            descriptionKey: "developer.playground.ai_features.sample.science_climate.description",
            descriptionFallback: "Science and climate article for testing summarization quality and categorization edge cases.",
            body: """
            Ocean heat content in the upper two thousand meters of the global ocean reached a new annual maximum in 2025, according to the latest analysis published by the International Climate Observatory. The dataset combines Argo float profiles, satellite altimetry, and reanalysis products, and shows an accumulated energy uptake equivalent to roughly 25 zettajoules over the past twelve months.

            Lead author Dr. Helena Souza explained that the result is consistent with a continued warming trend driven by greenhouse gas emissions, modulated by a moderate La Niña phase in the equatorial Pacific. "The atmosphere captured the headlines this year, but the ocean is where most of the energy is stored, and that storage is still increasing," Souza said in a briefing in Geneva.

            The report identifies three regional hotspots: the North Atlantic subpolar gyre, the western Pacific warm pool, and the Mediterranean basin. In the Mediterranean, sea surface temperatures were on average 1.6 degrees Celsius above the 1991 to 2020 baseline, contributing to widespread coral bleaching off the Balearic Islands and an unusually long marine heatwave south of Sicily.

            The authors stress that ocean heat content is a relatively low-noise indicator of long-term climate change, in contrast to year-to-year surface temperature variability. Using it as a benchmark, the team projects that global mean surface temperature has a 64 percent probability of exceeding 1.5 degrees Celsius above pre-industrial levels for the calendar year 2026, slightly higher than last year's projection.

            Policy implications were highlighted in a companion brief released by the United Nations Environment Programme, which called for faster deployment of renewable energy and a phase-out of unabated fossil fuels by 2040. Several delegations from small island states said the findings reinforce their case for stronger adaptation funding at the next climate conference.
            """
        )
    ]

    static func sample(id: String) -> Sample? {
        all.first { $0.id == id }
    }
}

#endif
