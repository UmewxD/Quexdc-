# Quexdc — a Creative Platform

Not just social media — a creative platform in the making. This Flutter app is
an early prototype for ideas, expression, curious people, and creative
collaboration. Some features are local demos; some ideas are still future
plans. The goal is to make the good stuff work before making it huge.

See the repository's [README](../README.md) for a quick introduction and its
[LICENSE](../LICENSE) for the proprietary notice. Third-party dependencies and
assets keep their own licenses. Copies of earlier revisions distributed with
the MIT License remain covered by the MIT terms that accompanied them.

## Easter Egg videos

The Easter Egg hunt is an append-only collection configured in
`lib/easter_shop.dart` in the `easterEggs` list. Keep existing IDs and entries
so players' found records and community guides remain valid; add a new
`EasterEgg` entry for each new video rather than replacing an old one. Each egg
has a stable ID, an in-app placement, a clue, and an optional HTTPS `videoUrl`.
Add a direct, playable video URL to enable its player. A video host used on web
must allow cross-origin playback. Use a direct MP4 or HLS stream URL; a regular
YouTube/Vimeo watch-page URL is not a playable stream for this player. The
placements are Inspiration Boards, Cloud Bar companions, and the region area.

Eggs remain in the collection; adding a video adds another hunt entry and does
not move or replace earlier eggs. Each egg can be claimed once per device:
skipping grants its base points, while watching the clip through grants the
larger reward. The app tracks forward playback progress rather than a seek bar.
Easter Points and shop ownership are currently stored locally and are not a
server-verified balance or marketplace currency. Use only clips you created or
have permission to share. For clips hosted by third-party video platforms,
check their terms before offering points for watching; incentivized views may
not be allowed. Do not treat local rewards as authoritative for real-money
purchases or competitive ranks.

## Stories and feed preferences

The Feed includes text-only stories that are removed from local storage after
24 hours, a local interest-based “For You” sort, and controls for choosing feed
topics. These are device-local prototypes: story audience labels are not access
controls, and posts, profiles, and direct messages are not shared or protected
by the configured Supabase project. Do not use them to store sensitive content.

Production audience tiers require authenticated user identities and server-side
authorization rules. AI recommendations/chatbots, biometric sign-in, face AR,
live video/calling, automatic translation, and VR rooms also need separate
providers, platform setup, and security/privacy review; they are not made live
by the local prototypes.

## Sponsor quest and streak prototype

The Quest Log includes device-local app-use and quest-completion streaks, with
a 48-hour repair option that spends 50 Easter Points once per recovery. These
balances and dates are not server-verified. There is also a clearly labeled
coffee-brand quest mock-up; it is not affiliated with Starbucks or another
brand. The selected image is kept in memory and is not uploaded or verified.
Submitting it only records a local demo-pending state and grants no reward.

Real sponsored offers require an actual partner agreement, a secure
verification/review service, a privacy and data-retention policy, and any
required age/region safeguards. Paid placements, referral commissions, cash
streak recovery, and purchases are not implemented. Do not ask users to make a
purchase for this prototype or represent points as money.

## Aesthetics and styled memos

The Marketplace includes creator-provided Frutiger Aero, Weirdcore, and
Mysticule starter palettes, along with seasonal/festival/regional-inspired
examples. Selecting a palette changes the app accent color; point-priced
examples use local Easter Points, not cash. Custom asset uploads, creator
licensing/revenue splits, and sales are not implemented. DM memo choices are
visual treatments only. Messages remain device-local in this prototype and are
not end-to-end encrypted.

## Inventor workspace prototype

The Marketplace's Inventor Workspace stores idea notes and self-reported
progress on this device. SharedPreferences is not encrypted, and these notes
are not a patent filing, proof of invention, confidential vault, or legal
service. Patent offices, governments, crowdfunding platforms, companies, and
funders are not connected. Funding preferences and optional donation
percentages are notes only; there are no payments, royalties, loans, or debt.
Users should check current patent and crowdfunding requirements with the
relevant official services and qualified advisers before publicly disclosing
sensitive ideas.

The Profile settings button opens **Ideas & beta**, a quiet overview of future
inventor/collaboration, creative marketplace, and community-care concepts. It is
informational only: it does not create spaces, publish user scores or titles,
apply account penalties, contact companies, or provide privacy guarantees.
Political-platform features are outside the scope of this Quexdc beta.

## Quexdc welcome montage

The Feed's play-circle button opens the welcome montage experience in
`lib/welcome_montage.dart`. The video slot is intentionally empty at first:
pressing **Play welcome montage** goes to the outro so the full post-video flow
can be tried now. Once a direct HTTPS video is ready, set
`welcomeMontageVideoUrl` to its URL. The player advances to the same outro when
the video ends; viewers can also skip ahead. The outro links back to the Feed,
Boards, Community Spaces, or the existing Feed without requiring a choice.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
