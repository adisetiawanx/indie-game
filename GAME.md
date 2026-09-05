# GAME.md - Slow Leaf

This file is the single source of truth for the game's design. Every future
coding session reads this file first. Design decisions listed here were made
together with Adi and should not be changed without his explicit approval.

## Pitch

Slow Leaf is a cozy incremental game about running a small tea house in the
countryside. You grow tea in the garden behind the house, process the leaves
into real tea varieties, and serve customers in the shop in front. The heart
of the game is the tea market and leaf aging. Pu-erh cakes you store gain
value in real time, even while you are away, so every day you decide between
selling now or waiting for a better price. Slow, warm, and quietly strategic.

## Identity

- Title: Slow Leaf (working title, confirmed by Adi)
- Studio: Ruvicode
- Engine: Godot 4.7.2 stable, GDScript, UI built via code (no editor drag-drop)
- Platform: Windows first. Mac, Linux and Steam Deck evaluated after the
  demo is solid
- Target store: Steam, price $4.99
- Quality bar: Very Positive rating. Scope stays small enough to reach that
  bar. Depth over volume.

## The Hook (what makes this game different)

The tea market and real-time leaf aging is the main hook.

1. Tea prices rise and fall based on seasons, events, and rumors
2. Pu-erh cakes age in real time and appreciate exponentially, including
   while the game is closed. A cake worth x1 today can be worth x4 in three
   real days. The player constantly weighs selling now against waiting
3. Rare visitors arrive at random (a tea elder, a wandering traveler, the
   village cat) and give boosts or special requests. Small daily dopamine

Supporting depth systems (all confirmed, implemented in this order after the
core loop is solid):

4. Blending: combine tea, herbs and flowers into named signature blends with
   their own reputation
5. Seasonal festivals: competitions with entry requirements, acting as
   milestone "bosses" for each season

## Core Loop (five stages, follows real tea processing)

1. Garden. Plant plots, tea grows in real time (with offline progress),
   harvest raw leaves
2. Processing. Raw leaves pass through stations (withering, rolling,
   oxidation, drying) according to each tea variety's recipe. Stations have
   queues and upgradeable capacity
3. Serving. Customers arrive based on reputation, order tea from stock,
   you serve, earn coins and reputation
4. Economy. Coins buy plots, stations, and automation helpers. Reputation
   attracts better customers
5. Discovery. Experimentation unlocks new recipes (white, green, oolong,
   black, and pu-erh which needs long real-time aging). Seasons change what
   can be planted

## Sources of Depth (anti-monotony, all confirmed)

a. Recipe discovery through experimentation
b. Seasonal customer demand rotation, forcing focus decisions each season
c. Customer types with different preferences (tourists, village elders,
   pu-erh collectors)
d. Automation layout optimization (helper and station placement)

## Progression Structure (target: 50 hours to "done", designed not grinded)

- Main progression: 10-12 hours to the first prestige decision
- Prestige cycles (Generations, 2-4 cycles): each cycle unlocks genuinely
  NEW mechanics, never just multipliers. This rule is critical, a 50 hour
  game must not feel like 20 hours repeated
- Real-time pu-erh aging naturally fills long-term playtime
- Collection codex: recipes, blends, elders
- Endgame, designed to never truly end:
  1. Vintage pu-erh collection with escalating tiers (3, 7, 30, 100 real days)
  2. Shop reputation climbing toward "village legend" with endless tiers
  3. Legacy blend archive
- DLC-ready content held back for later: winter season and iced teas, plus
  the shop cat

## Reset Layers (two, confirmed)

- Season (light reset, every 1-2 hours of play): resets the garden, keeps
  buildings, grants season bonuses. All economy numbers are balanced around
  both reset cycles from day one, or this layer gets cut (fallback: one
  prestige layer only)
- Generation (deep reset): a new family head inherits the tea house, resets
  daily economy, grants legacy points for an inner talent tree (30-50 nodes)

## Art Direction

- Scene and background art: AI-generated soft storybook illustration, one
  locked style via fixed prompts and reference images
- Small icons and UI elements: CC0 packs (Kenney) plus code-drawn UI
- UI style: flat, warm dark palette as the visual glue
  - Background: #0F0F0E
  - Accent: #D97757 (clay terracotta)
- No generic AI gradient aesthetics

## Audio

- Music: AI-generated lofi/ambient, 4-6 tracks per season, royalty free
  because we make them
- SFX: CC0 packs (Kenney audio)
- Audio is polish stage work, not M0

## Milestones

Every milestone produces a playable build Adi can run, never abstract work.

- M0 Vertical slice. Garden, processing, serving. No prestige. 30-45 minutes
  of content. Purpose: validate the feel of the loop
- M1 Full content. Prestige, market and aging, blending, festivals, the 50
  hour progression. This is the longest phase
- M2 Demo and store page. The demo is CUT FROM the finished game (Adi's
  explicit choice, a safety zone so the demo can never outshine the real
  game). Steam page goes live, wishlist collection starts. Steamworks fee
  $100 is paid at this point
- M3 Polish, Next Fest, 1.0 release. Release timing is driven by wishlist
  count and playtest feedback, not a calendar date

## Business Rules

- Price $4.99 (Adi's final call)
- Quality standard is the market bar for Very Positive, referencing Tiny
  Biomes (small team, 424 reviews, 85 percent, $4.99)
- Market reference points: Hearth and Hamlet (cozy incremental, 100k units
  in 7 days off a 125k wishlist), Alchemist's Garden (closest thematic
  competitor), Idyll Isle, Cozy Desktop Konbini

## Scope Guardrails

- Every feature must serve the 50 hour structure. Anything that does not is
  postponed to post-release updates
- Each prestige cycle must open new mechanics, not just bigger numbers
- Both reset layers are balanced from day one, or the Season layer is cut
- Polish comes before content volume. A small polished game beats a long
  mediocre one
- The demo must be cut from the real game, never built separately

## Division of Work

- Hermes agent: all code, scenes, asset pipeline (AI images, CC0 assets),
  automated tests (headless selftest, screenshot verification), builds and
  exports
- Adi: game design decisions, playtesting, art direction approval, audio
  preparation, and all store-facing choices
