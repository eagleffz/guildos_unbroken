# Changelog

## 2.5.0
- Updated for Guild OS 2: the tabs sit in Guild OS's rooms (Marketplace in Workshop, Board in Salão, My Char in Members, Keys in Raids).
- The version dot in the roster sits after the name and Guild OS's own marks again (it was gone with Guild OS 2).
- Main/offspec and version also show on a roster card kept open with Shift-click.

## 2.4.2
- Orders and marketplace entries (looking for / offering) of characters who left the guild are deleted, once the name has been missing from the guild roster for 5 minutes.

## 2.4.1
- Keys: whoever has no Seal of Ascension yet shows the three gems in the UBRS column (Spirestone, Smolderthorn, Bloodaxe): owned in color, missing in grey. The cell tooltip names the missing ones and their boss; the UBRS header lists who is on the way with how many gems.

## 2.4.0
- New tab "Keys": who in the guild has which endgame key (Shadowforge Key, Key to the City, Skeleton Key, Crescent Key, Seal of Ascension, Drakefire Amulet) and attunement (Molten Core, Blackwing Lair, Naxxramas). Found by itself in bags, key ring, bank and finished quests, and synced with the guild. `/gkeys` opens it.

## 2.3.3
- Removed the in-game popup about a newer version (and `/gco version`). The version dot in the Guild OS roster stays.

## 2.3.2
- Role colors: tank blue, healer green, damage red, for the whole spec name (My Char buttons, roster tooltip). The chosen spec is marked with a gold bar.

## 2.3.1
- Role icons (tank, healer, damage) next to the specs: in the "My Char" tab and in the Guild OS roster tooltip.

## 2.3.0
- Main spec and offspec moved into their own tab, **My Char** (`/gspec`, `/mychar`), which also shows what the guild sees.

## 2.2.0
- **Main spec and offspec** for every character: set with the "My specs" button in the marketplace tab or `/gspec`, shown with the role in the Guild OS roster tooltip, synced across the guild. Druids pick Feral as tank or as damage.

## 2.1.0
- Orders and marketplace are one tab, **Marketplace**, with two sub-tabs: **Looking for** and **Offering**.
- **Looking for**: one form for everything you need. A craftable item becomes a crafting order (take, deliver), "for skilling" a skilling call, anything else a plain request answered with "Have it".
- **Offering**: items and services, answered with "Want it".
- **Lockpicking** is a known service: suggested while typing, shown in every player's language, and rogues are notified (with a sound) when someone looks for it. The tooltip lists the guild's rogues.
- Filters: All · For me · Items · Services · Mine (Looking for), All · Items · Services · Mine (Offering).

## 2.0.0
- Renamed from GuildOS_CraftOrders to **GuildOS_Unbroken**. The old addon is switched off when both are loaded.
- Marketplace with offers and requests for items and services.
- Crafters' specializations in the order tooltip.
- Removed the group planner and the dungeon log.
