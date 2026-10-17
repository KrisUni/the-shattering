# ADR-0001: Build each area as an Open map, with Rooms for buildings and the Dungeons

- **Status:** Proposed
- **Date:** 2026-10-17
- **Authors:** KrisUni, drafted with Claude

## Context

The Shattering is a top-down 2D action RPG with souls-lite combat. The player moves freely in any direction, locks on to circle an enemy, is chased by enemies in Pursuit, and runs back to their Remains after dying. All of this needs open space where an enemy can follow the player and the camera can frame a fight around the enemy rather than around a screen edge.

The game also wants the room-by-room feel of classic top-down adventures inside smaller buildings, and a Dungeons area built as a prison of separate cells and corridors, where moving from one Room to the next is part of the escape.

The first five areas are fully connected: the player can return to any of them at any time, including the arch tree after escaping it. This decision sets how every area is built, so changing it later means rebuilding every scene.

## Options considered

- **Open maps only.** Each area is one continuous space. Chases and fights flow well, but the Dungeons lose the room-by-room escape they are meant to have, and small buildings become cramped corners of a large map.
- **Rooms only.** Every area is screen by screen, as in classic Zelda. It is the simplest structure to build, but every screen edge cuts a chase or a Lock-on fight short, and a run back to Remains becomes a string of screens.
- **One seamless world.** No loads anywhere. The world has to be streamed in pieces while the player moves, which is a large engineering cost for five areas. Full connection only needs areas to link in both directions, which doorways already provide.
- **Open maps with Rooms inside.** Chosen; see the decision below.

## Decision

Each area is an Open map: one continuous space that the camera follows the player through. Smaller buildings inside an Open map, and the whole of the Dungeons, are built from Rooms: screen-sized spaces where leaving through an edge or a door moves the view to the next Room. Open maps join each other through doorways or paths with a short load. An enemy in Pursuit follows the player through a Room's exit after a short delay, so a Room exit is never a safe spot.

## Consequences

- Chases, Lock-on fights and runs back to Remains flow inside an area, while buildings and the Dungeons can be made as small, self-contained Rooms.
- There are two kinds of space with two camera behaviours, one that follows the player and one fixed per Room, plus the transitions between them.
- An enemy in Pursuit has to carry its state, such as its Health, Stagger and Pursuit, across a Room exit, so enemy state cannot live only inside the Room it started in.
- State that must outlast a visit, such as burnt openings, Remains, killed Bosses and the Fugitive standing, has to be kept per area outside the spaces themselves, because the player can leave and come back at any time.
- The delay before a pursuing enemy comes through an exit needs tuning in play, so that a doorway is neither a trap nor a refuge.

## References

- #1 — the first five areas, which this decides the structure for.
- `CONTEXT.md`: Open map, Room, Pursuit.
