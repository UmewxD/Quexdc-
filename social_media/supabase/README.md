# Community font marketplace setup

The marketplace uses Supabase for email-link sign-in, font file storage, public
listings, and license requests. Payments are intentionally not enabled; listings
are free and license requests let creators discuss permission directly.

## Set up the free development backend

1. Create a Supabase project and open its SQL Editor.
2. Run `migrations/20261108090000_font_marketplace.sql`.
3. In **Project Settings → API**, copy the project URL and the public
   publishable key (or legacy `anon` key). Never put a `service_role` or secret
   key in this app.
4. In **Authentication → URL Configuration**, allow the exact local or deployed
   app URL you use. Configure the email provider/template so sign-in links return
   to that URL. For local Flutter web, add `http://localhost:7357` if that is
   the URL printed by `flutter run -d chrome`.
5. Start the app with:

   ```sh
   flutter run -d chrome \
     --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
     --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLIC_PUBLISHABLE_KEY
   ```

   The publishable/legacy `anon` key is designed to be included in a client app;
   Row Level Security policies in the migration protect writes. These values are
   public app configuration, not server secrets. Keep any future
   payment-provider secret keys on a server/Edge Function, never in Flutter.

6. For a release web build, pass the same two `--dart-define` values to
   `flutter build web --release`.

The app remains usable without the two values, but the marketplace displays a
setup message and cannot share data until a Supabase project is configured.

## Current marketplace behavior

- Users sign in with an emailed magic link; no password or payment account is
  needed.
- Signed-in users can publish `.ttf` and `.otf` fonts up to 5 MB, set a creator
  name, add attribution/license text, and confirm they have permission to share.
- Anyone can browse/download listed fonts; signed-in users can apply one to the
  app or send a licensing request.
- Creators can see incoming requests and approve/decline with a reply.
- A creator name shown on a profile is a display label. Authentication user IDs
  control upload and request permissions.

Font authors are responsible for the accuracy and legality of their license
terms. This initial version does not sell fonts, collect money, verify
copyright ownership, or provide legal advice. Review and moderation workflows
are still needed before opening a public production marketplace.

## Community Spaces setup and privacy

Community Spaces are optional themed hangouts for sharing messages. They are
not a replacement for Zoom, and this feature does not currently provide video
calls. The feature has a local mode that works without Supabase.
Local rooms and messages are stored only in this app's preferences on this
device. Their invite codes do not work on other devices.

To enable shared rooms, run
`migrations/20261111010000_escape_dimensions.sql` in the Supabase SQL Editor
after configuring the project above. The feature calls narrowly scoped
`SECURITY DEFINER` RPCs using the public app key; it does not sign in as, or
replace, the Quexdc profile account. The database stores hashes of invite
codes and high-entropy room membership tokens. The app keeps the membership
token locally so it can reopen the room. Losing app/browser storage loses that
room membership; the invite code can be used to join again.

Invite codes only control who can join a room. Messages are not end-to-end
encrypted and can be accessed by project operators with database privileges.
Shared text posts expire from the app's room view after 24 hours; rooms stop
accepting joins after 30 days. Expired records are not automatically erased
from the database by this migration. Three distinct room memberships reporting
a post hide it from the room, but this is not a substitute for active human
moderation. Do not promise users confidentiality, identity verification, or
moderation that the app does not provide.
