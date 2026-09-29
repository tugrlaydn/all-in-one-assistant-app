---
id: A14
title: "Design tooling — Figma for screens, SwiftUI for motion, Blender for rendered assets"
tier: A
status: ratified
proposed: 2026-09-28
ratified: 2026-09-29
owner_note: "ratified in chat: \"ratify all\""
---

# A14 — Design tooling — Figma for screens, SwiftUI for motion, Blender for rendered assets

The owner asked for Blender for UI and animation design. Here is the honest case, then the proposal.

**What Blender is good at, for this project: rendering.** Anything that is a *picture* — a layered app icon with real glass and refraction, the five habit-category glyphs as small rendered objects, an empty-state illustration, hero images for the README — Blender does better than any 2D tool, and an agent can drive it end to end through the connected Blender MCP: build the scene, render, hand back PNGs. It can also produce a short MP4 *motion study* of the Horizon accordion so we agree on the choreography — what moves first, what overlaps, how long — before a line of Swift exists.

**Why Blender cannot be the UI design tool.**
1. *It has no idea what a Mac window is.* No SF Pro, no SF Symbols, no Liquid Glass material, no auto-layout, no light/dark, no hover, focus, or keyboard states. A Blender render of a Settings pane is a painting of a Settings pane; every real screen has dozens of states a render cannot hold.
2. *Nothing comes out the other end.* There is no path from a Blender scene to SwiftUI — no tokens, no components, no measurements the code can consume. Every design decision would be re-typed by hand, and would drift.
3. *Its animation model is the wrong one.* Blender animates keyframes on a timeline. SwiftUI animates with physics — a spring has a response and a damping — and the interesting part of the Horizon is what happens when you press → *during* an animation: it retargets mid-flight. A video cannot show retargeting, interruption, or trackpad scrubbing, and that is exactly where the feel lives.
4. *Iteration speed.* A layout tweak in Figma or an Xcode Preview is a click; in Blender it is a re-render.
5. *Control.* Blender is not a tool the owner works in. A design source of truth the owner cannot open is one the owner cannot control — the opposite of the rule in §0.

**The proposal: three tools, each owning exactly one thing.**

| Tool | Owns | Produces | Owner reviews as |
|---|---|---|---|
| **Figma** (connected) | Screens, components, tokens, states, light/dark, spacing — the design source of truth | Frames the agent turns into SwiftUI through the Figma design-context tools; motion specs via Figma's motion data | Figma frames, comments in Figma |
| **SwiftUI Motion Lab** (in the app, debug builds only) | Interaction and motion truth: spring response/damping, durations, overlaps, retargeting | The numbers in `DesignKit.Motion`, ratified by the owner | The running app with live sliders, a Reduce Motion toggle, and a "record 5 s" button that saves an MP4 for the report |
| **Blender** (connected) | Rendered assets; optional motion studies | Icon layers, category glyphs, illustrations, hero renders — PNG/MP4 into `App/Resources/` and `docs/reports/img/` | PNG or MP4 in the report — never a `.blend` file |

Rules that follow: no screen is built before its Figma frame is ratified (P2 onward); no motion number lives anywhere but `DesignKit.Motion`; every Blender output is a rendered file, and `.blend` sources live in `Design/blender/` for the agent, not for the owner.

**If the owner still prefers Blender for UI, the plan can do it.** It would be recorded as an owner override with these costs stated once: screens designed as renders, no design→code path, and motion agreed on video rather than in hand. Say so and D8 becomes "Blender for UI"; nothing else in the plan breaks.
