# sound-s

An original Hebrew/RTL music experience with a responsive violet-and-charcoal interface, continuous HTML audio playback, local playlists, favorites, Spotify embeds, and an optional Supabase community backend.

## Run locally

```sh
python3 -m http.server 4173
```
Open http://localhost:4173. No build step or package install is needed. The Supabase client is vendored at version 2.95.3. Fonts use Google Fonts with system fallbacks. Album artwork is loaded directly from Spotify image hosts.

## What works immediately

- 147 verified real Spotify tracks across ten artist collections, with original artwork, Hebrew/English search, artist filters, pagination and direct source links. Metadata was retrieved from Spotify on 2026-10-27.
- Persistent official Spotify embed panel: previews or full playback are controlled by Spotify availability/account rules. The panel continues while browsing or minimized; closing it stops playback. Transport/volume/seek for Spotify are controlled inside the official embed, not the local HTML audio controls.
- The former six synthesized demos are hidden from discovery but retained for backwards compatibility with saved local playlists. No commercial audio files are downloaded or redistributed.
- Play/pause, seek, volume, next/previous, shuffle, repeat, and supported system Media Session controls.
- Playback continues on a background tab subject to browser/OS policies. Closing the tab stops playback.
- Search, mood filters, favorite tracks, and named local playlists survive refresh using localStorage.
- Add personal audio files without uploading them. Object URLs work during the current visit only; reselect files on a later visit. Do not add these temporary files to a cloud playlist.
- Paste an official Spotify track/album/artist/playlist URL to open its official embed. Spotify decides playback availability and duration. The custom audio player pauses when opening the embed. Closing/replacing the embed stops its audio.

## Catalog maintenance

`catalog.js` stores public metadata, original source links and image URLs only. It does not store playback tokens or audio previews. Names and URLs are preserved as returned by Spotify. Artist grouping is based on the source collections; one track may occur in several collections. Public reporting accepts Spotify track IDs as well as hosted tracks. Catalog removals are made in `catalog.js`; admin UI does not claim to remove the original song from Spotify.

## Optional cloud features

The UI and backend schema are implemented; **they are not live until you configure your own Supabase project**. No passwords or fake accounts are stored locally. Disconnected auth, uploads, and reporting cannot submit and are labeled clearly.

See [SETUP.he.md](SETUP.he.md) for Hebrew setup instructions.

With configuration in place:
- Google OAuth and verified email/password registration, recovery, persistent sessions.
- Account-based favorites and private/public playlists; public playlist links.
- Audio uploads into a private bucket, initially `pending`.
- Admin-only approval/rejection; approved tracks become discoverable.
- Public reporting through a bounded database RPC, admin-only report review.

`supabase/schema.sql` must run once in a **new** project. It includes RLS and storage access policies. Account administrators are assigned manually through SQL, never through the public application. Uploads are manually reviewed for content, licensing and file validity; this is not an automatic malware scanner or copyright detector. Add an automated scanning pipeline and CAPTCHA/edge rate limiting before broad public promotion. The report RPC currently caps intake globally at 100/hour to bound storage; it is not a substitute for abuse protection.

### Security and privacy

- Only put the Supabase public publishable/anon key in `config.js`. Never put `service_role`, Google secrets, or privileged tokens in source.
- Private audio is served with one-hour signed URLs after a policy check. Revocation prevents new URLs; issued URLs may work until expiry.
- Users cannot approve their uploads, alter someone else's playlists, read reports, assign themselves admin, or replace reviewed files through the supplied policies.
- Public playlists expose their name and ordered track IDs. Private playlists are visible only to their owner.
- Personal reports are visible only to administrators. Configure retention and a privacy policy for your deployment.
- Do not accept uploads until an administrator is assigned and prepared to review them.

## Deployment

The GitHub Actions workflow publishes only application assets to Pages on pushes to `main`. Enable Pages → Source → GitHub Actions. GitHub Pages serves the frontend; Supabase supplies authentication, database and storage. Backend configuration is independent of Pages deployment.

## Verification

JavaScript syntax, audio asset format, local HTTP delivery and browser interactions are checked during development. Live Google/email auth, cross-account RLS, real upload/review and reporting integration require your configured backend and must be verified using the setup checklist before enabling real users.

## Credits

Visual identity and instrumental demos created for sound-s. The audio generator is in `scripts/generate_audio.py` (Python + NumPy). Original demo audio may be used in this project; no commercial recordings are bundled. Supabase JS is MIT-licensed; see `vendor/LICENSE.supabase`. Google Fonts: Heebo and Manrope, SIL Open Font License. Spotify and Google are third-party services; sound-s is an independent project.
