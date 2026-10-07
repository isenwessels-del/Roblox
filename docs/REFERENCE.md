# Steal An Egg reference research

Research date: **7 October 2026**. This records public information that was actually accessible from the cloud workspace. It does not claim that the linked gameplay video was watched or that the original game's private implementation was inspected.

## Identified public experience

Roblox's official search API returned **Steal An Egg**, created by the verified group **and Collect Rare Pets**. The official experience metadata API independently returned the same name, creator and description:

- [Public experience](https://www.roblox.com/games/107778070777162/Steal-An-Egg)
- Root place ID: `107778070777162`
- Universe ID: `10563114921`
- [Official experience metadata](https://games.roblox.com/v1/games?universeIds=10563114921)
- [Official place-to-universe lookup](https://apis.roblox.com/universes/v1/places/107778070777162/universe)
- Reported maximum players: **7**; avatar type: **R15**; categories: **Simulation / Tycoon**.

This is the leading exact-name search result and the working reference. The supplied share link could not be resolved, so its identity cannot be conclusively matched to this result.

## Confirmed advertised mechanics

The public Roblox description explicitly advertises:

1. Steal eggs from pets.
2. Hatch eggs to collect rare pets.
3. Earn money from pets.
4. Upgrade the treadmill and base.
5. Train on the treadmill to gain Speed.
6. Steal eggs from other players.
7. Discover rarer eggs, pets, sizes and mutations.
8. Desktop, console, mobile and tablet support.

The [official game-pass listing](https://apis.roblox.com/game-passes/v1/universes/10563114921/game-passes?passView=Full&pageSize=100) also returned two public passes: **X2 MONEY!**, described as "Earn x2 more money!", and **X2 GROWTH SPEED!**, described as "Eggs grow x2 faster!". This corroborates money generation and an egg-growth mechanic. It does not establish the growth duration or size formula. The returned prices were 399 and 467 Robux respectively; these are reference metadata, not purchase products configured in this project.

These support a house-themed adaptation with obtainable boxed prefab houses, a timed build/reveal step, income-producing collectible houses, player-to-player theft, running-speed training, base upgrades and collectible variants. The ordering and exact rules beyond the advertised actions are design choices in this project.

## Actual access outcomes

| Source | Outcome |
| --- | --- |
| [User's Roblox share link](https://www.roblox.com/share?code=9af4d727a1adb142b2173902db985d9a&type=ExperienceDetails&stamp=1791326213087) | Network proxy rejected the connection with `403 Forbidden`; no page content or destination identity obtained. |
| [User's YouTube video](https://www.youtube.com/watch?v=dKSLQOBpJ0k) | Network proxy rejected the connection with `403 Forbidden`; video and transcript were not obtained. |
| [Official Roblox search](https://apis.roblox.com/search-api/omni-search?searchQuery=Steal%20an%20Egg&pageToken=&sessionId=7a931d65-58a4-4b40-b609-a1fe9f2a1b42) | HTTP `200`; exact-name public listing, description and identifiers obtained. |
| Official share-link resolver, `POST https://apis.roblox.com/sharelinks/v1/resolve-link` | The service was reachable. After its normal CSRF handshake it returned HTTP `401`: `User must be authenticated to use 'ExperienceDetails' links`. No account credentials were supplied, and the share destination remains unverified. |
| Official experience metadata and place-to-universe APIs, linked above | HTTP `200`; matching identifiers, description and maximum-player setting obtained. |
| Official modern game-pass listing, linked above | HTTP `200`; two named passes and their descriptions obtained. |
| [Official media metadata](https://games.roblox.com/v2/games/10563114921/media) | HTTP `200`; four image entries listed, but images were not obtained or inspected. |
| [Official thumbnail API](https://thumbnails.roblox.com/v1/games/icons?universeIds=10563114921&size=512x512&format=Png&isCircular=false) | Network proxy rejected the connection with `403 Forbidden`. |
| Google and Bing searches for `Roblox "Steal an Egg"` | Network proxy rejected both connections with `403 Forbidden`. |
| Official universe badges API | Network proxy rejected the connection with `403 Forbidden`. |
| Legacy official experience game-pass listing route | HTTP `404`; no purchase data obtained. |

Blocked sources were not routed through proxies or alternate download services. Available official APIs supplied the factual reference instead.

## Details that remain unverified

The original map dimensions, base geometry, camera framing, menus, button arrangement, models, animations, sounds, prices, income rates, carry rules, hatch durations, training gains, upgrade formulas, rarity odds and mutation names were not available. The description does not establish a conveyor, rebirth system, base-lock timer, combat system or offline income rules.

House art, interfaces, timings and economy values in this repository are implemented choices, not verified reproductions of those details. A playable house adaptation can be completed from the confirmed loop; an exact visual or mechanical match cannot honestly be asserted from these sources.
