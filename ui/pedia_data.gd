extends RefCounted
## Everything the Pedia says. One place for the words, so a page can never
## disagree with another page and the layout code stays free of prose.
##
## The book has three layers, and this file is the bottom two:
##  1. CHAPTERS — the table of contents (Islands, Plants, Animals, Equipment);
##  2. SUBCHAPTERS — the things inside a chapter, one per subject;
##  3. the data page a subchapter opens: its plate, its name and its text.
## A subchapter record *is* its data page's content; that is why there is no
## separate list of pages here.
##
## Chapter ids and subchapter ids are load-bearing:
##  - `equipment` ids are exactly `items/item_db.gd`'s keys (the test enforces
##    it), so an item can never exist without a data page;
##  - `plants` / `animals` ids are the species file names in flora/ and fauna/;
##  - `islands` ids are the four outlines in `world/island.gd`.
##
## Later: this list is the natural place to filter by what the player has met —
## `encountered` would become a per-record flag and open() would ask the savegame.

const CHAPTERS := [
	{
		"id": "islands",
		"title": "Islands",
		"blurb": "Four landmasses, laid out like Japan and named after it. This is the map the world is built from — real geography at about 1:1000, with real names on the capes and straits.",
	},
	{
		"id": "plants",
		"title": "Plants",
		"blurb": "Twelve species, all of them strange. Most of them glow, chime, hover or hunt, and each has a real plant standing behind the idea.",
	},
	{
		"id": "animals",
		"title": "Animals",
		"blurb": "Six species. Four ignore you until you hurt them, one is the reason to watch the dusk, and one nobody has explained.",
	},
	{
		"id": "equipment",
		"title": "Equipment",
		"blurb": "What the drone can carry: weapons, armour and the odds and ends the island leaves lying about.",
	},
]

const SUBCHAPTERS := {
	"islands": [
		{
			"id": "ezo",
			"name": "Ezo",
			"subtitle": "Hokkaido · 北海道 · aynu mosir",
			"text": "The island the drone arrives on, named after Hokkaido's old name — what the island was called until the Meiji government renamed it Hokkaidō (北海道, \"Northern Sea Circuit\") in 1869.\n\nReal Hokkaido is the northernmost and second-largest of Japan's main islands: 77,984 km² for the island, about 83,424 km² as a prefecture, close to the size of South Carolina, and home to only about five million people — the lowest population density in Japan. Its highest point is Daisetsuzan's Asahi-dake at 2,291 m, and its climate is continental: heavy snow, sea ice on the Okhotsk coast, and a boreal forest of Ezo spruce and Sakhalin fir.\n\nThis world is a homage at roughly 1:1000. The cape where you wake stands in for the Oshima peninsula and Hakodate — the port you would arrive at by ferry. The northern tip is Cape Sōya, the northeast cape is Shiretoko (a UNESCO peninsula of cliffs and drift ice), the southern spike is Cape Erimo, the eastern lowlands are the Kushiro wetlands, the highland in the middle is Daisetsuzan, and the caldera is a Tōya-style deep clear lake.\n\nHokkaido is the Ainu homeland — aynu mosir, \"the land of humans\" — and most of its place names are Ainu words: Shiretoko (\"the end of the earth\"), Kushiro (\"river mouth\"), Tōya (a lake), Sōya, Erimo, and Daisetsuzan's kamuy mintara, \"the playground of the gods\". The survey crew kept the old island name; nobody has bothered naming the planet.",
		},
		{
			"id": "honshu",
			"name": "Honshu",
			"subtitle": "本州 · the mainland",
			"text": "The largest island, and the one that makes the archipelago a country: 227,960 km² — the seventh-largest island on Earth and the second most populous — with over 100 million people, more than 80% of Japan.\n\nIt runs 1,300 km from the Tsugaru Strait in the north to the Kanmon Strait in the south, with 10,000 km of coastline. Its backbone is the Japan Alps (Hotaka 3,190 m, Kita-dake 3,193 m), crossed by the Fossa Magna rift; Mount Fuji, at 3,776 m the country's highest and most photographed mountain, stands apart as a lone stratovolcano. The Kantō Plain around Tokyo is the largest flat land in Japan. The Shinano, at 367 km, is the longest river; Lake Biwa, near Kyoto, is the largest lake.\n\nThe coast faces two very different worlds: the Japan Sea side is one of the snowiest places on Earth, while the Pacific side is a subduction coast — the Nankai Trough offshore has produced the great earthquakes of 1707, 1854, 1946 and 2011, and the tsunamis that came with them.\n\nIn the build, Honshu is terrain: the Alps, Fuji, the Tōhoku and Chūgoku ranges and the Kii peninsula are all hills and biomes, with the Oga peninsula drawn as its own small blob off the north coast. Nothing is placed on it yet.",
		},
		{
			"id": "shikoku",
			"name": "Shikoku",
			"subtitle": "四国 · \"four provinces\"",
			"text": "The smallest of the four main islands — 18,802 km², nearest in size to New Jersey — and the least populous of them: about 3.6 million people, and depopulation is the defining fact of its modern life.\n\nIt is a mountain island. The spine holds Mount Ishizuchi (1,982 m), the highest mountain in western Japan, and the island is heavily forested: Kōchi prefecture is roughly 84% forest. Its rivers are its pride — the Shimanto, 196 km, is known as 最後の清流, \"the last clear stream\", the last big undammed river in Japan.\n\nShikoku faces Honshu across the Seto Inland Sea, the calm water that was for centuries the main highway of Japan, and Kyushu across the Bungo Channel. The Seto islands are drawn in the game as a scatter of six small islets between the two coastlines.\n\nTwo things are worth knowing about it: the island is ringed by the 88-temple pilgrimage, the ohenro, one walking loop of 88 stops; and it has no bears — the Asiatic black bear was extirpated here early in the 20th century. Its wolves went the same way.",
		},
		{
			"id": "kyushu",
			"name": "Kyushu",
			"subtitle": "九州 · \"nine provinces\"",
			"text": "The southernmost of the four, 36,782 km² — closest in size to Maryland — with about 12.4 million people, and the most volcanic ground in Japan.\n\nAso is one of the largest calderas in the world, 25 by 18 km with an active cone inside it; Sakurajima erupts often enough to dust Kagoshima with ash; and the Kirishima hills rise to the south. Beppu and Kurokawa are hot-spring country — Beppu alone claims more onsen sources than anywhere else on Earth. On the west side, the Ariake Sea has Japan's largest tidal range, about six metres, and its biggest tidal flats, where mudskippers live.\n\nKyushu is also Japan's front door. It lies closest to the Asian mainland — Korea is only about 200 km away across the strait — and history arrived through it: the Mongol invasions of the 13th century, the Portuguese and Dutch traders at Nagasaki and Dejima, and the earliest Christianity and firearms in the country.\n\nIn the build, Kyushu is the destination of the boat route, and an Aso-style cone and the Kirishima hills are modelled as terrain bumps — the caldera itself is not carved. It has no content of its own yet.",
		},
	],
	"plants": [
		{
			"id": "windsinger",
			"name": "Windsinger",
			"subtitle": "Aerophonex columnaris · Massif, NE Cape",
			"text": "A hollow, branchless column eight to fifteen units tall, tapering as it rises, with a crown of thin spines at the top and faint rings glowing at the trunk's segments.\n\nWind moving through the hollow trunk makes a deep organ note, and each tree has its own pitch: the longer the column, the lower the note. Stand in a grove and you hear a slow chord that changes as the wind does.\n\nThe groves are also where Windvane Gulls nest — inside the hollow trunks, where a bird's eggs are kept warm by the drone of the tree.\n\nThe real-world echo is the pairing of standing dead wood and cavity-nesting birds in Hokkaido's forests, above all Blakiston's fish owl (シマフクロウ), the largest owl in the world, of which only about 130 are left. To the Ainu it is kotan-kor-kamuy, \"the god that protects the village\" — a god that lives in a hollow tree and asks you to listen. The Windsinger is the same invitation with the bird left out.",
		},
		{
			"id": "sunbulb",
			"name": "Sunbulb",
			"subtitle": "Lumenradix esculenta · SW Cape, wetland edges",
			"text": "A squat plant: one glossy orange bulb half buried in the soil, glowing warmly, which dims the moment it is picked.\n\nIt photosynthesizes hard enough to cook its own corm, and the bulb is what you get for it — full of water and sugar. This is the drone's food, worth fifteen energy, and the reason the SW Cape meadows are worth walking.\n\nReal-world anchor: plants that store water and sugar underground are the reason wetlands can be crossed at all — the Ainu diet leaned on such roots, among them the bulb-forming *Allium victorialis* (Ainu プクサ pukusa, \"Ainu onion\") and Japanese butterbur. Eat what the bog grows, and keep walking.",
		},
		{
			"id": "lantern_reed",
			"name": "Lantern Reed",
			"subtitle": "Phosphostachys virgata · Wetlands, caldera shore",
			"text": "A thin reed two to three units tall with a teardrop-shaped seed head that glows cyan and sways in the wind.\n\nThe seed heads charge in daylight and glow all night, so a stand of them looks like a line of streetlights across the bog — and reeds don't grow where the ground is too soft to hold them. Anything that lights a path through a marsh is worth trusting.\n\nReal-world anchor: Kushiro Marsh in eastern Hokkaido, Japan's largest wetland, is the opposite kind of landmark. It is flat, dark, and easy to walk into the wrong way, and what it is famous for is a bird rather than a plant: the tanchō, the red-crowned crane (タンチョウ), Hokkaido's official bird, which survives there because people decided it should.",
		},
		{
			"id": "mirrorlily",
			"name": "Mirrorlily",
			"subtitle": "Speculiflora rotunda · Caldera Lake only",
			"text": "A floating disc one to two units across, with a mirror-chrome upper surface and a dark rim underneath. It sits on the caldera lake and reflects the sky so cleanly that birds will attack their own reflections.\n\nThe larger discs are natural platforms: they hold your weight, and they bob when you land on them.\n\nThe lake they float on is a stand-in for Lake Tōya in Hokkaido — deep, clear, and famous for the island sitting in the middle of it. A mirror laid on water is the simplest possible picture of that idea: the lake showing you the sky instead of its own bottom.",
		},
		{
			"id": "glasspetal",
			"name": "Glasspetal",
			"subtitle": "Vitripetala campana · Massif, NE Cape",
			"text": "A waist-high bellflower whose petals are transparent silica. Wind through a patch of them makes a high, glassy tinkling — a pitched counterpoint to the Windsingers' drones, and the closest thing the massif has to a village bell.\n\nThe petals shatter if something sprints through them and grow back over a day, so a patch that has gone quiet tells you that something moved through it — and how recently. Listen to the flowers instead of the footsteps.\n\nReal-world anchor: bells, wind chimes and glass chimes are a working part of Japanese gardens and shrines — the sound of 風鈴 fūrin on a summer evening is meant to make heat feel cooler. Here, the material is grown rather than blown, and the sound carries information.",
		},
		{
			"id": "embermoss",
			"name": "Embermoss",
			"subtitle": "Pyrotapetum molle · hummocks, highland rocks, hot-spring lines",
			"text": "A carpet of red-orange moss that follows the ground it grows on, glowing the whole time.\n\nIt dims where it is stepped on and brightens again slowly, so your footprints glow behind you for a few seconds — a trail you cast in your own shape. Pebble Scuttlers graze its edges and dim it as they pass the same way.\n\nIt is also the one plant the world gives a story to before you find it: Embermoss is described as growing on old hot-spring lines, and Japan sits on four tectonic plates with roughly 111 active volcanoes. Beppu alone has some 2,900 hot-spring sources. Where the ground has been hot once, something still grows in the shape of it. There is no vent in the game yet — the moss is currently the only evidence that there ever was.",
		},
		{
			"id": "thornlash",
			"name": "Thornlash",
			"subtitle": "Flagellumspinex agilis · SW Cape tallgrass, wetland margins",
			"text": "A coiled tendril about two units long, studded with hooked thorns, very hard to see until it moves.\n\nIt is an ambush hunter. Anything warm that comes within three units is lashed, after which it recoils for about five seconds — an opening in which you can take whatever it was guarding. It is the first hazard the world offers and the first lesson it teaches: some things in this landscape assess you before you assess them.\n\nReal-world anchor: plants that move fast enough to notice are rare and memorable — Venus flytraps in bogs, the sensitive plant オジギソウ that folds its leaves at a touch. In Japan the thorned, grasping plant with real folklore is the bramble イバラ, the thicket that the legend says caught the fleeing gods and the one that catches a careless walker.",
		},
		{
			"id": "sporebell",
			"name": "Sporebell",
			"subtitle": "Vaporcapsa alta · Wetlands, NE Cape",
			"text": "A tall pale dome cap on a stem about a unit and a half high, pulsing faintly the whole time.\n\nCome within two units and it releases a soft cloud of spores. The cloud hangs where it is, blurs everything seen through it, then disperses. Harmless — but it feeds the Lantern Drifters, which gather where the spores are thickest.\n\nReal-world anchor: spore clouds are how ferns, mosses and mushrooms get anywhere at all, and in a wetland they are also how the water gets its plant life started. The game's rule that popping one calls a drifter is borrowed from mushroom biology: a burst of spores is an announcement, and something is always listening for it.",
		},
		{
			"id": "hoverfern",
			"name": "Hoverfern",
			"subtitle": "Levifrons pumilio · Massif (densest), caldera rim",
			"text": "A small fern whose spore clumps hover half a unit to a unit above it, faintly violet, bobbing gently in place.\n\nElectrostatic lift keeps them airborne; walk through them and they drift off for a while before finding their way back.\n\nReal-world anchor: Japan's forests are full of ferns, and Hokkaido's are boreal — under Ezo spruce and Sakhalin fir, the forest floor is a deep green carpet. The game replaces the moisture-and-shade explanation for what grows there with electricity. The result is the same picture: a quiet forest where small things float where you are not looking.",
		},
		{
			"id": "frostneedle",
			"name": "Frostneedle",
			"subtitle": "Cryoconifera acuta · Central Massif",
			"text": "A conifer analog six to ten units tall with ice-blue needles and a frost-sheened trunk. Antifreeze sap keeps it from freezing solid, and its blue cones are edible — they taste faintly of cucumber.\n\nThis is the densest cover on the island, and the only place on the massif where a Dusk Stalker has a hard time finding you.\n\nReal-world anchor: Hokkaido's great boreal forest is Ezo spruce (エゾマツ, *Picea jezoensis*) and Sakhalin fir (トドマツ), with creeping Japanese stone pine (ハイマツ) above the treeline and white birch (シラカバ) coming up wherever the forest has been cut. The Ezo spruce is Hokkaido's official tree. A tree that can hold water without it freezing is the honest summary of how these forests survive a Hokkaido winter.",
		},
		{
			"id": "pulsegrass",
			"name": "Pulsegrass",
			"subtitle": "Pulsogramen radians · SW Cape meadows, highland benches",
			"text": "Ordinary-looking meadow grass that carries waves of soft light sweeping across whole slopes.\n\nAn entire meadow pulses on a shared rhythm of about twenty seconds, and each region's wave travels in a slightly different direction. Learn the directions and the grass becomes a compass: you can tell which slope you are standing on with your eyes shut.\n\nReal-world anchor: Japan's grasslands are mostly managed ones — 茅場 kayaba, the hay meadows cut for thatch and fodder, kept open for centuries by people. The synchronised wave adds a second, older layer to the same idea: a meadow is a single body with a rhythm, whether that rhythm comes from harvest or from light. Ainu song and dance likewise keep a shared beat to keep a group moving as one.",
		},
		{
			"id": "ghostsilk",
			"name": "Ghostsilk",
			"subtitle": "Parasitex filum · everywhere plants cluster, worst on NE Cape",
			"text": "A pale thread-vine that webs over other plants. An infested clearing is white: husks, threads, and nothing else.\n\nIt is a parasite. It drains Sunbulbs and Lantern Reeds dry and leaves bleached skeletons standing, so an area webbed in Ghostsilk is an area where light has been taken out of the ecosystem. Cutting it — with a tool you do not have yet — releases the trapped light as a heal burst.\n\nReal-world anchor: dodder ネナシカズラ is the classic thread-like plant with no leaves and no roots, coiled around its host and drinking from it. Hokkaido's forests also carry an older, stranger parasite story in the same shape: lichens and dwarf mistletoes that turn a stand of trees into white skeletons over years. Quiet, slow, and total.",
		},
	],
	"animals": [
		{
			"id": "grazer",
			"name": "Velvetback Grazer",
			"subtitle": "Cervocorpus mollis · SW Cape meadows, highland benches",
			"text": "A deer-analog about 1.2 units tall with six low legs and a moss-green velvet back, grazing in herds of three to five on Sunbulbs.\n\nIt wanders for two to six seconds, walks to a point three to eight units away, and repeats. If the drone comes within six units it flees directly away at twice its walk speed for four seconds, then settles back into wandering.\n\nHurt one and it stops running: it charges at five units per second and rams for four.\n\nThe real Hokkaido has a deer of its own, and it is the reason the island's forests are in trouble: the Ezo sika deer (エゾシカ) recovered from near-extinction and then ran out of predators — the Hokkaido wolf went extinct around 1889, and the deer have been browsing young forest ever since. It is also, in Ainu and Japanese story, food and coat and antler and pest, all at once.",
		},
		{
			"id": "scuttler",
			"name": "Pebble Scuttler",
			"subtitle": "Petroscutellum laterale · coastlines, caldera rim",
			"text": "A knee-high crab that walks sideways, stone-gray shell with lichen patches on it — genuinely easy to mistake for a rock until it moves.\n\nIt grazes the edges of Embermoss carpets, dimming the moss as it goes its own way. Come within three units and it scuttles off at three times its walking speed, body always facing you, because that is what a crab does.\n\nHurt one and it comes back at you, hopping, and pinches for three.\n\nReal-world anchor: Japan eats crab the way it eats most seafood — with regional ceremony. Hokkaido's prized one is the king crab (タラバガニ), which is technically not a true crab at all; the red snow crab and the hairy crab 毛蟹 are the local icons. A crab that looks like the shore it lives on is the version of this you can find anywhere, if you look twice.",
		},
		{
			"id": "drifter",
			"name": "Lantern Drifter",
			"subtitle": "Aeromedusa lucens · wetlands, anywhere at night",
			"text": "A balloon-bell a unit and a half across with glowing tendrils hanging from it, floating two to five units up.\n\nIt drifts: a slow linear move, about half a unit a second, in a wind direction that rotates over time, bobbing gently. It feeds on Sporebell spores and turns toward clouds of them to linger. It ignores the drone completely — until it is hit, when the tendrils reach, the wind turns on you, and it sinks to head height to sting.\n\nReal-world anchor: a lantern that floats over a marsh and does not care about you is the picture behind every light-over-water story in Japan — the kitsune-bi of the folklore, the distant lamp of a boat, the glow of fireflies (ホタル) over a river in June. The wetlands look inhabited because of the Drifters, which is exactly what those stories do for a real marsh.",
		},
		{
			"id": "gull",
			"name": "Windvane Gull",
			"subtitle": "Circulus alatus · overhead everywhere, most visible over Windsinger groves",
			"text": "A falcon-gull analog with wide stabiliser wings. It never lands.\n\nEach one flies a slow circle around a fixed anchor point, twenty to forty units out, with a slight vertical bob; flocks of two to four circle landmarks at staggered heights. Gulls going round and round in one place is a landmark hint: something interesting is below them.\n\nHurt one and it stoops at nine units a second, coming down to just above head height to strike for four, and returns to its circle afterwards from wherever the fight left it.\n\nReal-world anchor: gulls work for the same reason they work in any harbour — the water brings food up, so the air above it is worth circling. Shiretoko's cliffs in Hokkaido hold one of the densest seabird colonies in Japan, and the birds there trace the same long, patient circles over the same ledges.",
		},
		{
			"id": "rippleback",
			"name": "Rippleback",
			"subtitle": "Undosaurus lacus · Caldera Lake only",
			"text": "A six-unit swimmer whose segmented back plates break the surface in a row, like moving islands.\n\nIt loops a wide rounded triangle under the lake surface and surfaces for about five seconds every forty to seventy seconds, then dives again. Nobody knows what it eats. The survey crew has one blurry photograph.\n\nHit it and it answers: it comes up, charges at five units per second, and rams for eight — the hardest blow any animal in the game lands. It cannot follow you out of the water, so the fight ends the moment you climb ashore.\n\nReal-world anchor: a large animal living in a lake that nobody has properly surveyed is not far-fetched. Lake Tōya has an island in the middle of it; Lake Biwa has its own endemic species. And every deep Japanese lake has a story about something down there that is bigger than what is caught.",
		},
		{
			"id": "stalker",
			"name": "Dusk Stalker",
			"subtitle": "Noctursor venator · Central Massif, NE Cape (never near spawn)",
			"text": "A low-slung quadruped, matte black, with a faint red eye-strip that gives it away at distance. It patrols alone between two or three fixed points inside a territory of about thirty units, and it hunts at dusk.\n\nIt is the only animal in the game that attacks on sight: come within ten units inside its territory and it will chase at half again your walking speed, closing, stopping, telegraphing for four-tenths of a second — and then biting for five. Watch for the wind-up and walk out of reach. After dark it sees fourteen units instead of ten; the night is its shift.\n\nPosition matters more than bravery: it gives up outside its territory, and a hit makes it personal — provoked, it follows you anywhere until it loses you.\n\nReal-world anchor: Hokkaido had a wolf, *Canis lupus hattai*, and it was extinct by about 1889 — the last of Japan's two wolf subspecies, gone within living memory of the Meiji era. What Hokkaido has now instead is the Ezo brown bear (ヒグマ), the largest land animal in Japan at 300-400 kg. The Dusk Stalker stands in for both: the predator that is out there, and the one that was erased.",
		},
	],
	"equipment": [
		{
			"id": "sword",
			"name": "Katana",
			"subtitle": "long sword · 25 damage · a new run starts with it",
			"text": "The drone's main weapon and the reason a fight is possible on the first stroll. One left click swings it: a cone 2.2 metres deep and about ±0.7 radians ahead, 25 damage, drawn as a crescent trail that sweeps through the arc, with four ticks at the crosshair when the swing actually connects.\n\nReal-world anchor: the katana (刀) is the curved Japanese long sword — a single-edged blade with a differential heat treatment, hard at the edge and tough at the spine, worn edge-up through a sash and drawn as one motion. Ritually, blades were said to hold the will of their owner. Here, the drone simply found one.",
		},
		{
			"id": "dagger",
			"name": "Tanto Dagger",
			"subtitle": "short blade · 12 damage",
			"text": "A short blade for the times the katana is the wrong tool: faster to bring up, less reach, less damage.\n\nReal-world anchor: the tantō (短刀) is the Japanese short blade, a companion to the long sword rather than a lesser version of it — worn indoors where the long sword stayed at the door, and used at close quarters. Samurai carried the pair, and the pairing is the point: the reach you cannot have in a doorway is the reach you do not need in one.",
		},
		{
			"id": "bow",
			"name": "Yumi Bow",
			"subtitle": "ranged · 15 damage per arrow",
			"text": "Hold right click to draw, release to fire. An arrow flies with a mild drop, sticks where it lands, and does 15 damage; arrows are consumed from the stack.\n\nThis is the weapon that reaches an animal before it knows you are there — which matters, because every animal in the game fights back once it has been hurt, and being able to start that at range is a real advantage.\n\nReal-world anchor: the yumi (弓) is the Japanese bow, asymmetric — two thirds of its length above the grip — and tall enough to be fired from a kneeling position, from horseback, or from the deck of a boat. Japanese archery (kyūdō) is a standing ceremony as much as a sport: the shot is meant to be the calmest thing in the room.",
		},
		{
			"id": "arrows",
			"name": "Arrows",
			"subtitle": "ammunition · five per pickup",
			"text": "Ammunition for the bow, five to a stack, spent straight out of the inventory when you release a shot.\n\nThe Dusk Stalker drops them about half the time it dies, which makes the island's most dangerous animal also its most useful supplier — go in with the katana, walk away with arrows.\n\nReal-world anchor: arrows were made in Japan with bamboo shafts, waterfowl feathers and steel heads, in workshops that also made the bows; the fletching of a Japanese arrow is as particular as anything else in the tradition. Five of them is not many, which is the point: ranged damage is a resource.",
		},
		{
			"id": "shield",
			"name": "Wooden Shield",
			"subtitle": "off hand · a board between you and the bite",
			"text": "A plain wooden board, light enough to carry and thick enough to stop a claw pinch, made rather than grown. It cannot be equipped as armour — it is an inventory item — but it is the island's evidence that something here once expected a fight.\n\nReal-world anchor: Japan fought with shields far less than Europe did — the Japanese shield tradition is thin, closer to a portable wooden screen (立て板 tate-ita) used by archers and defenders behind fortifications than to a knight's shield. For a drone with no hands free, the honest thing to build is the thing that stands between: a board.",
		},
		{
			"id": "leather_armor",
			"name": "Leather Armor",
			"subtitle": "worn · absorbs 30% · 80 durability · press E in the inventory",
			"text": "The only armour in the game so far, and the only defence against the fact that a bite hurts. Worn, it eats 30% of every blow that lands on the drone and loses durability doing it — roughly 53 mid-sized hits before it is used up. Press E on its slot to put it on.\n\nThe armour sits behind the same damage pipeline as everything else: it takes its share first, then the rest goes to the drone's energy. When it breaks, the boot is silent — you find out the next time something bites.\n\nReal-world anchor: Japanese armour (甲冑) is a laced lamellar tradition — small plates, bound with silk cord, designed for a horse archer who needed to move his arms and to look, from a distance, like the leaves of a tree.",
		},
		{
			"id": "flint",
			"name": "Flint Shard",
			"subtitle": "material · sharp, grey, found on the shore",
			"text": "A struck shard of stone with an edge that cuts. A crafting material for now, and the second-oldest tool in human history wherever you find it — the first thing that turns a rock into a decision.\n\nReal-world anchor: 火打石 hiuchi-ishi, the fire-striking stone, is the same idea in Japanese: flint struck against steel for sparks. Flint-sharpening and stone tools sit under every later Japanese craft tradition — blades are the family this shard belongs to, and the katana in your hand is a very late descendant of it.",
		},
		{
			"id": "stick",
			"name": "Driftwood Stick",
			"subtitle": "material · straight, dry, salt-stained",
			"text": "A straight length of driftwood, dry and salt-stained, carried up the beach. A crafting material, and the most useful thing in the world: with a stick you can reach further, lean on something, and make fire burn where you want it.\n\nReal-world anchor: driftwood is a real resource on a Hokkaido beach — and a real problem, too, since Japan's coastlines catch timber from everywhere and the Oyashio current delivers it. Anything washed-up is free, and everything free gets used.",
		},
		{
			"id": "vine",
			"name": "Vine Cord",
			"subtitle": "material · roughly one metre, ties anything",
			"text": "A length of tough green vine, harvested in the tallgrass. A crafting material — cordage is the quiet technology: bind a stick to a shard and you have made an axe out of two things that were nothing.\n\nReal-world anchor: 葛 kuzu, Japanese arrowroot, is the classic Japanese cordage plant — a fast-growing vine that was used for rope, baskets, cloth and even food, and that is still a nuisance today. Its fibre is strong enough to hold weight; that is all a cord has to do.",
		},
		{
			"id": "kana_charm",
			"name": "Kana Charm",
			"subtitle": "keepsake · a red pouch with a loop of cord",
			"text": "A small red pouch with a gold cord loop and a written character on it. Found, not made. The character is kana — one of the two Japanese syllabaries, the writing system a child learns first — and it is the first piece of language the world hands you.\n\nReal-world anchor: this is an omamori (お守り), an amulet bought at a shrine or temple, sewn shut around a blessing you are not supposed to read. Millions are sold every year: for safe driving, for exams, for a good birth. They are usually kept for a year and then returned to be burned. The kana on this one is the hook the game's language puzzles hang from: study the script, and the world's writing starts to mean something.",
		},
		{
			"id": "shell",
			"name": "Spiral Shell",
			"subtitle": "keepsake · a smooth cone with a chip at the mouth",
			"text": "A large spiral shell, smooth, with the lip chipped where someone once blew it. It is a keepsake and a crafting material — and the chip is a hint about the first of those two uses.\n\nReal-world anchor: this is a 法螺貝 horagai, a conch-shell trumpet. Mountain ascetics sounded it to announce themselves on a pilgrimage route; it was a war horn and a ritual instrument, one of the few objects that is both. A shell you can blow is the oldest way of telling the landscape where you are.",
		},
		{
			"id": "emberstone",
			"name": "Emberstone",
			"subtitle": "loot · always dropped by a Dusk Stalker",
			"text": "A rough orange stone, warm to the touch. It is the guaranteed drop from every Dusk Stalker, which makes it the only thing in the game you can farm deliberately from something dangerous — a fight that pays for itself.\n\nA crafting material for now. In a world where the glowing plants are named after gods visiting, a stone that holds heat after it is picked up is exactly the kind of object that should not be lying around.",
		},
	{
			"id": "notebook",
			"name": "Pedia",
			"subtitle": "the drone's own notebook · brown leather, carried from the start",
			"text": "A brown leather notebook, and the object this book is: the drone's research notes, carried from the first minute of a run. Everything you read in the Pedia is written in it — the four islands, the twelve plants, the six animals, and what the drone can carry.\n\nThe notes survive you. Dying wipes what you were carrying, but not the notebook: it is the drone's own record of the island rather than loot, so a respawn brings it back, carried rather than held — along with the pen that writes it and the Magnifying Glass the entries are drawn through. The book starts empty and fills by hand: plants are drawn where they grow with the Magnifying Glass, animals are either watched through the Binoculars or killed with a blade and opened up, islands write themselves down as you land on them, and equipment is noted the moment it is picked up.\n\nNo real-world anchor needed: a field notebook is the oldest research instrument there is. Naturalists in Japan kept them by the thousand — Kumagusu Minakata (1867-1941), who walked the Kumano forests and filled his with fungi, slime moulds and folklore, is the patron saint of the form: a book that is evidence, not decoration.",
		},
	{
			"id": "binoculars",
			"name": "Binoculars",
			"subtitle": "observation tool · watch an animal for eight seconds, out to 45 m",
			"text": "Two barrels, lenses forward, carried from the first minute of a run — and one of the two ways an animal gets into this notebook. Equip them, left click with the crosshair on a living animal, and hold it inside the two circles for eight seconds: the drone watches it and draws it, and the entry appears in the Animals chapter.\n\nDistance is the point. These reach forty-five metres, which is what makes an animal that flees at twice your walking speed drawable at all: you find it, you stop, you watch. Lose it — walk away, look elsewhere, or let it slip off the crosshair for more than a moment — and the drawing starts again from nothing. It is meant to be an observation, not a snapshot.\n\nThey are for animals, and for watching rather than handling: a plant has to be looked at closely with the Magnifying Glass, and so does a body. Click the wrong thing and the drone will say which tool to use instead.\n\nReal-world anchor: 双眼鏡 sōgankyō, \"two-eyed mirror\", the field glasses that turned watching animals into a discipline. Japan has one of the oldest birdwatching cultures in Asia — the Wild Bird Society of Japan was founded in 1934 — and the country's cranes, owls and seabirds are counted by volunteers every year with exactly this equipment. A notebook, a pair of binoculars and patience: the whole apparatus of natural history, unchanged.",
		},
		{
			"id": "magnifying_glass",
			"name": "Magnifying Glass",
			"subtitle": "close-observation tool · draws a plant, or opens a body",
			"text": "A loupe with a short handle, carried from the first minute of a run. It is the close-work instrument: a hand's reach of distance, six metres at most, and the tool for two of the three ways a page gets written.\n\n**A plant** is drawn where it grows, by observation: equip the glass, left click with the crosshair on the plant, hold it in the lens for eight seconds, and write the note — the drone's own pen does the writing. That is how the whole Plants chapter fills.\n\n**A dead animal** is drawn by **autopsy**: what a blade killed is left lying as a specimen, and examining that with the glass for eight seconds opens it up and records it. This reaches exactly the page the binoculars would have reached by watching the animal alive — two routes, one entry.\n\nIt will not watch a living animal; that is what the binoculars are for, and the drone will say so if you try. Nothing alive is opened by this tool: the specimen has to be dead first.\n\nReal-world anchor: 虫眼鏡 mushimegane, \"insect-mirror\", the hand lens. The whole of small natural history was made with one — Linnaeus' students, Darwin's barnacles, and, closer to this island, Minakata Kumagusu identifying slime moulds on his own hands and knees in the Kumano woods. A loupe is how you look at a thing until it stops being a shape and becomes a species; it is also how a specimen gets opened and read.",
		},
		{
			"id": "pen",
			"name": "Pen",
			"subtitle": "writing tool · the drone's own, never lost",
			"text": "A dark fountain pen, carried from the first minute of a run and kept for good: the notebook is where the drone's drawing goes, and this is what writes it. It is a keepsake like the notebook — death takes the drone's loot, not its notes or the tools that make them.\n\nNothing in the game asks you to pick it up or select it. Every entry the Magnifying Glass draws and every thing the survey notes down is written in ink you are already carrying; the pen is the reminder that the notebook is a written object rather than a list the game keeps for you.\n\nReal-world anchor: Japan writes with 万年筆 mannenhitsu, the \"ten-thousand-year brush\", and before that with brush and inkstone — the writing habit that gave the country one of the world's highest literacy rates centuries before Europe got there. Field notebooks in Japan, as everywhere, were filled with a pen: Minakata Kumagusu's notes on fungi, folklore and astronomy run to thousands of pages, written by hand.",
		},
	],
}


## What a chapter says when nothing is drawn in it yet: the notebook starts empty
## and fills by being out in the world, so an empty chapter has to tell the player
## how it fills (Maurice's rule: species are drawn by studying them).
const EMPTY_HINTS := {
	"islands": "Nothing here yet. An island writes itself down once you stand on it — or moor off its coast.",
	"plants": "Nothing drawn yet. Equip the Magnifying Glass, put the crosshair on a plant and hold it for eight seconds.",
	"animals": "Nothing drawn yet. Watch one through the Binoculars for eight seconds — or kill it with a blade and examine what is left with the Magnifying Glass.",
	"equipment": "Nothing yet. What the drone carries is noted down as soon as it is picked up.",
}


static func chapters() -> Array:
	return CHAPTERS


static func chapter(id: String) -> Dictionary:
	for c in CHAPTERS:
		if c["id"] == id:
			return c
	return {}


static func chapter_title(id: String) -> String:
	return str(chapter(id).get("title", ""))


static func subchapters(chapter_id: String) -> Array:
	return SUBCHAPTERS.get(chapter_id, [])


static func empty_hint(chapter_id: String) -> String:
	## The line a chapter shows while nothing in it has been drawn yet.
	return str(EMPTY_HINTS.get(chapter_id, "Nothing here yet."))


static func subchapter(chapter_id: String, subchapter_id: String) -> Dictionary:
	for e in subchapters(chapter_id):
		if e["id"] == subchapter_id:
			return e
	return {}


static func subchapter_ids(chapter_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for e in subchapters(chapter_id):
		out.append(str(e["id"]))
	return out