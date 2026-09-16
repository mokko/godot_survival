# Geography of the Japanese archipelago — reference for Survival M

Companion to `research/old.md` (worldbuilding, Ainu layer, premise) and the world-building canon
in `flora/plants.md` + `fauna/animals.md`. This file is about the **real geography** the game is a
homage to, and what of it is actually in the build today.

Status markers used throughout:

- ✅ **in the game** — exists in `world/island.gd` (terrain/biomes) or as placed content.
- ⚠️ **partial** — present as a name/biome/analog only.
- ❌ **not in the game** — real feature with no implementation yet.

Canon reminder: the map is **Japan at (nominally) 1:1000**, Ezo + Honshu + Shikoku + Kyushu, **no
Okinawa**, single player, north = −Z, east = +X. Keep that canon; this doc is material to feed it.

---

## 0. Conventions, units and scale (read this before trusting any number below)

| | |
|---|---|
| Orientation | north = −Z, east = +X (`island.gd` header) |
| Water level | `WATER_LEVEL = 0.0`; caldera lake `LAKE_LEVEL = 2.5` |
| Map grid | `GRID_MIN(-210, -150)` → `GRID_MAX(410, 760)`, i.e. **620 × 910 units** |
| Terrain mesh step | 2.5 units |
| Player speed | walk **5.0 units/s**, sprint **10.0 units/s** (`player.gd`) |
| Day length | 1200 s real time = 20 min (Minecraft) |

**The stated 1:1000 is approximate.** The code comment on Honshu says "1:1000, km arc coords × 0.9",
but measured against the real islands the compression is not uniform:

| Island | real extent | in-game extent (units) | measured units per real km |
|---|---|---|---|
| Hokkaido / Ezo | ~430 km SW cape → NE cape | 285 × 233 | ≈ 0.85 |
| Honshu | 1,300 km long, 50–230 km wide | 454 × 482 (long axis ≈ 662 diagonal) | ≈ 0.5 |
| Shikoku | 225 km long, 50–150 km wide | 195 × 65 | ≈ 0.85 |
| Kyushu | ~300 km N–S, ~200 km E–W | 220 × 120 | ≈ 0.4–0.7 |

So Ezo and Shikoku are drawn *relatively larger* than Honshu and Kyushu: the four islands are a
homage with preserved shapes and relative positions, not a single uniform projection. A literal
1:1000 map of Japan would need a ~2,000-unit grid (≈2.2× the current one) and roughly 2.5× the
terrain vertices — the compression is almost certainly a performance choice, and it is fine to keep.

**Travel time implications (straight line, flat, no detours):**

| Route | walk @5 | sprint @10 |
|---|---|---|
| Ezo across (285 u) | 57 s | 29 s |
| Honshu long axis (~662 u) | 2 min 12 s | 66 s |
| Shikoku (195 u) | 39 s | 20 s |
| Kyushu (220 u) | 44 s | 22 s |
| whole map N–S (910 u) | 3 min 2 s | 91 s |

**Vertical exaggeration ≈ 4–5×.** The in-game peak height is roughly `2.2 + amplitude`:

| Feature | real height | in-game | factor |
|---|---|---|---|
| Fujisan (Honshu, amp 14.0) | 3,776 m | ~16.2 u | 4.3× |
| Daisetsuzan massif (Ezo, amp 9.0) | 2,291 m | ~11.2 u | 4.9× |

Two other deliberate departures from physical reality:

- **Sea depth is roughly to scale**: offshore height is −3.5 u ≈ 3,500 m, which is about right for
  the Sea of Japan (~1,700 m average, ~3,700 m max). Nice accident, worth keeping.
- **Caldera depth is not**: the Ezo caldera floor is −12 u below the surface — 12 km at 1:1000,
  physically absurd (real Lake Tōya is 179 m deep). It reads as a *stylised* deep clear lake; leave
  it as fantasy, don't quote it as scale.
- **One sun arc for the whole archipelago**: `day_cycle.gd` uses `JAPAN_MAX_SUN_ELEVATION = 77°` for
  ~36°N, which is Honshu's mid-latitude. Ezo is ~43–45°N in reality (lower sun, much longer summer
  days), Kyushu ~31–33°N. ❌ seasonal day-length variation is not implemented.

---

## 1. Hokkaido 北海道 — *aynu mosir* ("human land", Ainu)

**The playable island.** In-game name **Ezo** (Hokkaido's old name), built from `OUTLINE`.

| | |
|---|---|
| Area | island **77,984 km²**; Hokkaido prefecture (incl. small islands) **83,424 km²** |
| US state comparison | **South Carolina** (82,933 km²) for the prefecture; the island alone is between **South Carolina** and **West Virginia** (62,756 km²) |
| Population | ~4.99 million (2025) — density ~60/km², Japan's lowest |
| Dimensions | ~430 km SW cape → NE cape; second-largest main island |
| Highest point | Daisetsuzan **Asahi-dake, 2,291 m** |
| Longest river | Ishikari, 268 km |
| Climate | humid continental (Dfb), subarctic in the north; heavy snow; **sea ice** on the Okhotsk coast |
| Japanese name | 北海道 *Hokkaidō* = "Northern Sea Circuit" (Meiji-era administrative coinage, 1869) |

### Geography
Central volcanic massif (Daisetsuzan) with Japan's largest alpine zone, two long peninsulas SW
(Oshima/Hakodate, where the ferry lands) and NE (Shiretoko, UNESCO, drift ice, cliffs). Eastern
plains (Kitami, Tokachi) and the Kushiro wetlands — Japan's largest marsh, home of the tanchō
crane. Caldera lake Tōya (deep, clear, island-in-lake) sits southwest of the massif. Volcanic and
seismic: this is the southern Kuril arc.

### Distinctive flora
- **Ezo spruce (エゾマツ *Picea jezoensis*)** and **Sakhalin fir (トドマツ *Abies sachalinensis*)** — the
  great boreal conifer forest; Hokkaido's official tree is the Ezo spruce.
- **Japanese stone pine (ハイマツ *Pinus pumila*)** — creeping alpine scrub above treeline.
- **White birch (シラカバ *Betula platyphylla*)** — the post-logging second growth that reads as "Hokkaido".
- **Ezosenryō / Japanese butterbur, Ainu onion (プクサ, *Allium victorialis*)**, **fuki**, and the
  in-game Frostneedle's real counterpart, the antifreeze-conifer idea.

### Distinctive fauna
- **Ezo brown bear (ヒグマ *Ursus arctos yesoensis*)** — Japan's largest land animal (~300–400 kg).
- **Blakiston's fish owl (シマフクロウ *Ketupa blakistoni*)** — world's largest owl, ~130 individuals,
  Ainu *kotan-kor-kamuy* ("god who protects the village"). A near-perfect real-world echo of the
  game's Windsinger/gull pairing.
- **Tancho red-crowned crane (タンチョウ *Grus japonensis*)** — resident breeder in **Kushiro**, the
  game's wetlands analog; Hokkaido's official bird.
- **Ezo sika deer (エゾシカ)**, **northern fox (キタキツネ)**, **Japanese pika (ナキウサギ)**, **Ezo red
  squirrel**, **sable**, and the now-extinct **Hokkaido wolf (*Canis lupus hattai*, gone by ~1889)**.

### In the game
- ✅ massif `FEATURES (-5, -20) amp 9.0 σ40` = Daisetsuzan; `(45, -45) amp 4.0` = Kitami/NE hills;
  `(-90, 10) amp 3.5` = SW highlands (Oshima).
- ✅ caldera lake `CALDERA_CENTER(-35, -20)`, `LAKE_RADIUS 13`, floor −12, rim to 0 at r=22 = Tōya.
- ✅ Kushiro wetlands: Gaussian flatten to 0.9 at `(75, 5) σ22`; biome `wetlands`.
- ✅ coasts: `sw_cape` (Oshima/Hakodate spawn), `ne_cape` (Shiretoko), `caldera_rim`, `massif`.
- ✅ flora/fauna: all 12 plant species and 6 animals are Ezo-only (`flora/plants.md`, `fauna/animals.md`).
- ❌ Ishikari-scale **rivers**, ❌ snow/sea-ice/season, ❌ drift ice, ❌ active volcanoes, ❌ brown bear
  (the Dusk Stalker is the predator stand-in).

---

## 2. Honshu 本州

| | |
|---|---|
| Area | **227,960 km²** — 7th largest island on Earth, 2nd most populous |
| US state comparison | **Utah** (219,887 km²), slightly smaller than Honshu; also close to **Idaho** (216,443 km²) |
| Population | 102.6 million (2020) — over 80% of Japan |
| Dimensions | 1,300 km long, 50–230 km wide, 10,084 km of coastline |
| Highest point | **Mount Fuji, 3,776 m** |
| Longest river | **Shinano, 367 km** (Japan's longest) |
| Largest lake | **Biwa, 671 km²** (Japan's largest) |
| Climate | humid continental north / humid subtropical south; **Japan Sea side is one of the snowiest places on Earth**; Pacific side gets typhoons |

### Geography
The backbone is the **Japan Alps** (Hida/Kiso/Akaishi; Hotaka 3,190 m, Kita-dake 3,193 m) with the
**Fossa Magna** rift crossing it; Fuji (3,776 m) as the isolated stratovolcano; **Kantō Plain**
(~17,000 km², Japan's largest, where Tokyo sits); Tōhoku highlands and the Kitakami/Abukuma ranges;
the **Chūgoku mountains** and the Kii peninsula; Lake Biwa in the fault basin near Kyoto. Japan's
Pacific side is a subduction coast — the **Nankai Trough** off it produced the great 1707/1854/1946
earthquakes and the 2011 Tōhoku event, with tsunamis.

### Distinctive flora
- **Japanese beech (ブナ *Fagus crenata*)** — the iconic cool-temperate forest of northern Honshu,
  with **mizunara oak (ミズナラ)** and **katsura (カツラ)**.
- **Sugi cedar (スギ *Cryptomeria japonica*)** and **hinoki cypress (ヒノキ)** — plantation conifers,
  and the two trees of Japanese sacred architecture.
- **Camphor (クスノキ *Cinnamomum camphora*)** and evergreen broadleaf in the warm south; **cherry
  (ソメイヨシノ *Prunus × yedoensis*)** as the cultural tree; **Japanese maple (イロハモミジ)**.

### Distinctive fauna
- **Japanese macaque (ニホンザル)** — the northernmost non-human primate; snow-monkey hot-spring
  bathing is a Honshu (Nagano) behaviour.
- **Japanese serow (ニホンカモシカ *Capricornis crispus*)** — a goat-antelope endemic to these islands.
- **Asiatic black bear (ツキノワグマ)**, sika deer, wild boar, **Japanese giant flying squirrel
  (ムササビ)**, and the **Japanese giant salamander (オオサンショウウオ *Andrias japonicus*)** — the
  world's second-largest amphibian, in Honshu/Kyushu/Shikoku rivers.
- **Crested ibis (トキ *Nipponia nippon*)** — extinct in the wild on Honshu 2003, reintroduced on Sado.
- Extinct: the **Japanese wolf (*Canis lupus hodophilax*)**, last confirmed 1905 — a mountain spirit
  (オオカミ) in folklore, and excellent story material.

### In the game
- ✅ `HONSHU_OUTLINE` (454 × 482 u, S-curve Aomori → Nihonkai → Kantō → Kii → Chūgoku), plus
  `OGA_OUTLINE` = **Oga peninsula, Akita** (a small separate blob, 25 × 29 u).
- ✅ features: Tōhoku `(200, 430) amp 7.0`; **Japan Alps** `(40, 300) amp 10.0 σ45`;
  **Fujisan** `(95, 390) amp 14.0 σ7`; **Chūgoku** `(-60, 485) amp 6.0`; **Kii** `(10, 520) amp 4.5`.
- ✅ biomes `alps`, `tohoku`, `chugoku`, `kii` exist in `BIOMES` — but **nothing is placed on them**.
- ❌ no Kantō Plain, ❌ no Lake Biwa, ❌ no rivers, ❌ no snow country, ❌ no flora/fauna
  (no C-fern/no species of its own — Honshu is terrain only).

---

## 3. Shikoku 四国 ("four provinces")

| | |
|---|---|
| Area | **18,802 km²** — smallest main island, 50th largest island on Earth |
| US state comparison | **New Jersey** (22,591 km²) is the nearest state; Shikoku is ~17% smaller |
| Population | ~3.6 million (2025) — least populous main island; heavily forested (Kōchi alone ≈ 84% forest) |
| Dimensions | 225 km long, 50–150 km wide |
| Highest point | **Mount Ishizuchi, 1,982 m** (西日本最高峰, "highest in western Japan") |
| Longest river | **Shimanto, 196 km** — often called 最後の清流, "the last clear stream", Japan's last big undammed river; **Yoshino, 194 km** |
| Climate | humid subtropical; typhoons; mild but rainy Pacific side |

### Geography
Rugged, sparsely populated, four prefectures (Tokushima, Kagawa, Ehime, Kōchi). Mountain spine
(Ishizuchi, Tsurugi) with narrow valleys; the **Shimanto river** and the Ashizuri cape in the south.
Separated from Honshu by the **Seto Inland Sea** (usually calm — the historical highway of Japan)
and from Kyushu by the Bungo Channel. Depopulation and abandonment are the defining modern reality.

### Distinctive flora
- Warm-temperate evergreen forest; **sudajii (スダジイ)** and oak; **Awa indigo (藍)** as a crop with a
  huge craft history.
- **Yakushima-like old growth** is absent here, but the Shimanto valley has relict riparian forest.

### Distinctive fauna
- **Japanese serow (ニホンカモシカ)** — Shikoku is a stronghold.
- **Japanese macaque**, sika deer, wild boar; **Japanese giant salamander** in the clear rivers.
- ❌ **no bears**: Asiatic black bears were extirpated on Shikoku (last records early 20th c.) — a real
  ecological difference from Honshu/Ezo, and a clean justification for "no dangerous megafauna here".
- Extinct: the **Shikoku wolf**, same fate as Honshu's, ~1900s.

### Culture that is geography-shaped (useful for the game)
- The **88-temple pilgrimage (お遍路 *ohenro*)** circles the whole island — a ready-made route structure
  if Shikoku ever gets content: 88 nodes, one loop, on foot.
- **Sanuki udon** (wheat, Kagawa) vs **Kōchi's katsuo tataki** — the food is a map of the terrain.

### In the game
- ✅ `SHIKOKU_OUTLINE` (195 × 65 u); feature `(-10, 680) amp 5.5 σ25` ≈ Ishizuchi; biome `shikoku`.
- ✅ the **Seto Inland Sea** exists: `SETO_ISLETS` = 6 small quads spanning x −55…48 at z 610–632.
- ❌ no rivers (the Shimanto is the most game-worthy river in Japan: undammed, clear, raftable),
  ❌ no flora/fauna, ❌ no pilgrimage/route structure.

---

## 4. Kyushu 九州 ("nine provinces")

| | |
|---|---|
| Area | **36,782 km²** |
| US state comparison | **Maryland** (32,131 km²) is the nearest; Kyushu is ~14% larger. Next up is West Virginia (62,756 km²) |
| Population | 12.4 million (2025) — 15th most populous island in the world |
| Dimensions | coastline 12,221 km; ~300 km N–S |
| Highest point | **Mount Kujū, 1,791 m** |
| Longest river | Chikugo, 143 km |
| Climate | humid subtropical, warm and very wet; typhoon landfalls; heavy rain on the southern mountains |

### Geography
The most volcanic part of Japan: **Aso** (one of the world's largest calderas, 25 × 18 km, with an
active cone), **Sakurajima** (a live volcano that rains ash on Kagoshima city), **Kirishima**; the
**Beppu / Kurokawa** hot-spring fields (Beppu has the most onsen sources in the world); the
**Ariake Sea** with Japan's **largest tidal range (~6 m) and biggest tidal flats**; the Chikugo
plain, rice country; Kyushu is the closest island to the Asian mainland (only ~200 km to Korea) and
historically Japan's gateway (Nagasaki, Dejima, the 13th-c. Mongol invasions).

### Distinctive flora
- Subtropical evergreens, **camphor, banyan-like *Ficus*, Chinese fan palm** in the south.
- **Yakushima cedar (屋久杉 *Cryptomeria japonica*)** on Yakushima (Kyushu region, ~504 km² island,
  Miyanoura-dake 1,936 m, UNESCO 1993): some cedars are dated at 2,000+ years, and the island's
  peaks catch up to ~10,000 mm of rain a year — among the wettest places on Earth. The single best
  real-world reference for the game's "ancient cold rainforest" look.
- **Mangroves** at the very southern tip (Kagoshima) — the only mangroves in the game's island set.

### Distinctive fauna
- **Izumi cranes (ナベヅル hooded crane, マナヅル white-naped crane)** — 10,000+ winter at the Izumi
  plain in Kagoshima, one of Asia's great crane gatherings.
- **Yakushima macaque (*Macaca fuscata yakui*)** and Yakushima sika deer — insular subspecies.
- **Ariake mudskipper (ムツゴロウ *Boleophthalmus pectinirostris*)** and mud-dwelling gobies — tidal-flat
  specialists, Japan's most distinctive intertidal animal.
- **Loggerhead turtles** nesting on Kyushu/Yakushima beaches; giant salamander in the rivers.
- Extinct: the **Kyushu (Hondo) wolf**, same 1900s loss.

### In the game
- ✅ `KYUSHU_OUTLINE` (220 × 120 u, z 595–715); features: **Aso-style caldera cone**
  `(-60, 655) amp 8.0 σ20` and **Kirishima hills** `(-100, 680) amp 4.0 σ18`; biome `kyushu`.
- ❌ the Aso caldera is a *terrain bump*, not a caldera — nothing is carved; ❌ no hot springs
  (🟡 but `flora/plants.md` already gives Embermoss "old hot-spring lines" as habitat — a hook with
  no world feature behind it yet); ❌ no tidal flats, ❌ no mangroves, ❌ no flora/fauna.

---

## 5. Cross-island geography (the part that makes the game teachable)

### 5.1 Blakiston's Line — the single best fact for this game
The **Tsugaru Strait** between Ezo and Honshu is a real faunal boundary, named for **Thomas
Blakiston** (a British naturalist living in Hakodate, who noticed in 1883 that Hokkaido's animals
are northern-Asian while Honshu's are southern-Asian). North of the line: brown bear, fish owl,
pika, no macaque. South of it: macaque, serow, black bear, no brown bear. The strait is ~20 km wide
and up to ~450 m deep — deep enough that it stayed a barrier even when land bridges formed
elsewhere. A second line (the **Watase Line**, at the Tokara strait north of the Ryukyus) does the
same job for Okinawa's fauna — which is exactly why excluding Okinawa from the map also excludes a
whole zoogeographic region.

**Use it:** it is a ready-made in-world reason why Ezo alone has the weird/cold flora, the only real
predator, the owl-analog and the kamuy pairing — and why Honshu/Shikoku/Kyushu could later be given
a *different* species set without breaking plausibility.

### 5.2 Climate and seasons — the biggest missing system
| Island | climate | snow | notable hazard |
|---|---|---|---|
| Ezo | humid continental / subarctic north | heavy; Okhotsk drift ice Jan–Mar | blizzards, sea ice |
| Honshu | continental north → subtropical south | Japan Sea side among world's snowiest | typhoons, Nankai earthquakes, tsunamis |
| Shikoku | humid subtropical, mild | rare | typhoons, heavy rain |
| Kyushu | humid subtropical, hottest/wettest | none | typhoons, volcanic ash, torrential rain |

❌ Nothing seasonal exists: `day_cycle.gd` runs a 20 min day/night loop only. `survival.md` notes
UnReal World's seasonal cycles as an ancestor — the obvious next survival system, and the geography
above says winter should bite hardest on Ezo (snow cover, ice, hypothermia, food scarcity).

### 5.3 Rivers, plains, lakes — mostly absent
- **Rivers:** Shinano 367 km (Honshu) is Japan's longest; Ishikari 268 km (Ezo); Shimanto 196 km
  (Shikoku, undammed); Chikugo 143 km (Kyushu). ❌ **no river carving anywhere in `island.gd`** —
  the terrain has no drainage at all. Rivers would be the highest-value terrain addition: they are
  landmarks, freshwater sources, travel routes, and they would make the wetlands read as a basin
  rather than a flat patch.
- **Plains:** Kantō ~17,000 km² (largest), plus Ishikari, Tsukushi, Nōbi. ❌ not modelled (terrain
  amplitude is Gaussian bumps only, no flat plains).
- **Lakes:** Biwa 671 km² and Japan's deepest, Tazawa 423 m. Only the Ezo caldera lake exists. ❌

### 5.4 Hot springs, volcanoes and the kamuy
Japan sits on four plates with ~111 active volcanoes. Beppu alone has ~2,900 onsen sources. Hot
springs are where the Ainu *kamuy* logic ("every natural force is a god visiting") is most at home,
and the game's canon already leans on kamuy pairing for the glow plants. ❌ No thermal feature
exists; 🟡 Embermoss is described as growing on "old hot-spring lines" — implementable as a
steaming vent scatter on the Ezo massif and around Kyushu's Aso cone.

### 5.5 Sea, fish and drift ice
The **Oyashio (cold) and Kuroshio (warm) currents** meet off Hokkaido → one of the world's richest
fisheries (salmon, kelp *konbu* — Hokkaido produces most of Japan's kombu). ❌ No fishing, no
currents, no drift ice, no tides; the sea is a flat alpha plane. Salmon runs and stranded kelp on
the Ezo coast would be cheap, high-value survival content (food, but also the seasonal clock).

### 5.6 Extinct animals as story
Both Japanese wolf subspecies died out within living memory of the Meiji era (Hokkaido ~1889, Hondo
~1905), and Honshu/Shikoku/Kyushu lost their black bears and Shikoku its wolves in the 20th century.
For a game whose premise is *finding out who you are*, in a world where a museum memorialises what
was erased, the wolves are the sharpest possible real-world anchor. `research/old.md` already carries
the "is the museum honest about what was erased" thread (Ainu layer) — the wolf belongs in it.

### 5.7 Ainu toponymy — naming material
Hokkaido's Ainu place names are descriptive and usable directly as in-world names:
**Shiretoko** (シリエトク, "the end of the earth"), **Kushiro** (クシロ, "pass/river mouth"),
**Tōya** (from Ainu *toya*, lake), **Daisetsuzan**'s Ainu name *kamuy mintara* ("playground of the
gods"), **Tokachi**, **Ishikari**, **Sōya**, **Erimo**. `flora/plants.md` already names the island
after Hokkaido's old name; extending Ainu names to the game's features is consistent, respectful and
free worldbuilding — flag any use to Maurice, who will want to check the Ainu layer himself.

---

## 6. Implemented vs real — consolidated

| Real feature | Game status | Where |
|---|---|---|
| Four main islands, relative positions | ✅ | `OUTLINE`, `HONSHU_OUTLINE`, `SHIKOKU_OUTLINE`, `KYUSHU_OUTLINE` |
| Oga peninsula (Akita) | ✅ | `OGA_OUTLINE` |
| Seto Inland Sea + islets | ✅ | `SETO_ISLETS` (6) |
| Tsugaru Strait separation | ✅ | ~20 u of open water south of Cape Erimo |
| Daisetsuzan massif | ✅ | feature amp 9.0 |
| Kitami / NE hills | ✅ | feature amp 4.0 |
| Oshima (SW cape), spawn at Hakodate-like arrival | ✅ | `sw_cape`, `SPAWN_XZ(-112, 82)` |
| Shiretoko (NE cape) | ✅ | `ne_cape` biome |
| Tōya-style caldera lake | ✅ | `CALDERA_CENTER`, `LAKE_RADIUS 13` |
| Kushiro wetlands | ✅ | Gaussian flatten at `(75, 5)`, `wetlands` biome |
| Japan Alps | ✅ | feature amp 10.0 σ45 |
| Mount Fuji | ✅ | feature amp 14.0 σ7 |
| Tōhoku / Chūgoku / Kii highlands | ✅ | features (biomes, no content) |
| Shikoku mountains (Ishizuchi) | ✅ | feature amp 5.5 |
| Aso caldera, Kirishima hills | ⚠️ | bumps only, no caldera carved |
| Vertical scale | ⚠️ | ~4–5× exaggerated |
| Horizontal scale | ⚠️ | ~0.4–0.85 u/km, non-uniform (not a clean 1:1000) |
| One sun arc (36°N) for all islands | ⚠️ | `day_cycle.gd`, no seasonal change |
| Flora/fauna | ⚠️ | Ezo only, invented species (12 plants, 6 animals) |
| Ground clutter everywhere | ✅ | `world/clutter.gd` (all land, not island-specific) |
| Rivers | ❌ | none |
| Plains (Kantō etc.) | ❌ | none |
| Lake Biwa | ❌ | none |
| Snow / seasons / drift ice | ❌ | none |
| Hot springs, active volcanoes | ❌ | none (Embermoss reference only) |
| Tides, currents, fishing, salmon runs | ❌ | none |
| Bears, macaques, serow, cranes, giant salamander | ❌ | not modelled; Dusk Stalker is the stand-in predator |
| Blakiston's Line as a *system* | ❌ | only geography; no fauna split |
| Okinawa / Ryukyus | ❌ by canon | deliberately excluded |

## 7. Opportunities this geography suggests (cheap → expensive)

1. **Island fauna sets** — the geometry is already there for `alps`/`kii`/`tohoku`/`chugoku`/
   `shikoku`/`kyushu` biomes that hold *no content at all*. Blakiston's Line justifies giving Honshu
   a different species list for free (no bears; macaque and serow instead).
2. **Rivers as landmarks** — drainage carving in `island.gd` + river-mouth biomes; the Shimanto
   (Shikoku) and Ishikari (Ezo) are the most evocative.
3. **Hot-spring vents** — a scatter of steaming vents on the massif and around the Aso cone, which
   finally justifies Embermoss's "old hot-spring lines"; pairs with the kamuy glow-plant logic.
4. **Seasons** — Ezo winter (snow cover, ice, food scarcity, the massif cold zone that
   `flora/plants.md` already promises for Frostneedle's cold resistance).
5. **Salmon run + kelp strandline** on the Ezo coast — seasonal food, and a reason to walk the beach.
6. **Ainu toponymy pass** over the Ezo features (with Maurice's review of the Ainu layer).
7. **The wolf thread** — extinct-predator lore tied to the "who are you / what was erased" premise.

## 8. Sources

Real-world figures above come from Wikipedia (accessed for this file):

- [Hokkaido](https://en.wikipedia.org/wiki/Hokkaido) (area 83,423.84 km² prefecture, population)
- [Honshu](https://en.wikipedia.org/wiki/Honshu) (227,960 km², 1,300 km, Fuji 3,776 m)
- [Shikoku](https://en.wikipedia.org/wiki/Shikoku) (18,801.73 km², Ishizuchi 1,982 m)
- [Kyushu](https://en.wikipedia.org/wiki/Kyushu) (36,782.37 km², Kujū 1,791 m, coastline)
- [List of islands of Japan](https://en.wikipedia.org/wiki/List_of_islands_of_Japan) (main islands)
- [Geography of Japan](https://en.wikipedia.org/wiki/Geography_of_Japan) (377,973.89 km²; Shinano
  367 km; Biwa 671 km²; hazards)
- [Blakiston's Line](https://en.wikipedia.org/wiki/Blakiston%27s_Line) (Tsugaru Strait boundary, 1883)
- [Wildlife of Japan](https://en.wikipedia.org/wiki/Wildlife_of_Japan) (subarctic north / subtropical south)
- [Yakushima](https://en.wikipedia.org/wiki/Yakushima) (location; old-growth cedar context)
- [List of U.S. states and territories by area](https://en.wikipedia.org/wiki/List_of_U.S._states_and_territories_by_area)
  (state comparisons; Montana 380,831 km²)

In-game figures are measured directly from `world/island.gd`, `player/player.gd`,
`world/day_cycle.gd` and `world/clutter.gd` (extents as of the current build).

Items marked *(verify)* are from general knowledge rather than a source pulled for this file and
should be checked before being quoted anywhere public.
