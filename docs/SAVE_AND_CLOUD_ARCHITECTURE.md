# Save, Autosave and Cloud Architecture

## Player-facing flow
1. Sign in with email OTP (no password).
2. Enter Character Name (first sign-in only; editable later in settings).
3. Play.

Character Name is game profile data, not a second credential. No guest-to-account migration wizard, social login, subscription, or extra profile form is part of V1.0.

## What is stored
Only game progress required to resume play: character name, world/region and location, fantasy date/season, inventory, unlocked progress, crop/animal/resource state, quest/story flags, and versioned save metadata. Do not store email, passwords, OTP codes, analytics identifiers, or unrelated personal data inside the game-save payload. Supabase Auth owns account identity; game_saves.user_id scopes the save row.

## Required behavior
- Local autosave every 30 seconds while dirty; best-effort save when the app pauses or closes.
- Offline play never depends on authentication or network availability.
- Keep newest local generation and mark cloud sync pending while offline.
- Cloud autosave every 60 minutes while online and authenticated.
- Retry pending upload automatically when connectivity returns.
- On reinstall/new device, sign in with the same email and restore the newest valid cloud save.
- Compare revisions and timestamps before restore/upload; never blindly overwrite a newer generation.
- Keep at least one recoverable previous generation; version every payload and provide migration handlers.
- Cloud failures must not block gameplay or local saving.

## Supabase project
Use the existing project named Aether Valley (project ref jieqdipddxkkextubbwa, region ap-southeast-1). Do not create another project. Existing public.game_saves uses (user_id, slot_id) as primary key and stores payload, schema_version, and updated_at. RLS must continue to restrict each operation to auth.uid() = user_id. Client apps may contain only a publishable/anon key; never embed a service-role key.

## Email OTP configuration dependency
Supabase email OTP uses the Magic Link email template. The template must include {{ .Token }} for a six-digit code. Verify existing Auth email template and SMTP delivery settings before testing sign-in.

## Current implementation boundary
The clean-start source currently implements local save scaffolding only. Supabase Auth UI, OTP send/verify, refresh-token lifecycle, remote upsert/fetch, offline sync queue, conflict resolution, and restore-on-login are not yet implemented or tested.

## Release acceptance tests
- Fresh install: Sign in -> OTP verify -> Enter Character Name -> Play.
- Local autosave: change progress, wait 30 seconds, force-close, relaunch; verify restored progress.
- Offline: play without network; local autosave continues and pending cloud state is retained.
- Online sync: verify only authenticated user's row changes.
- Reinstall/device restore: uninstall, reinstall, sign in with same email, restore latest cloud generation and character name.
- Conflict: newer local save must not be replaced by older cloud save; newer cloud save must be offered/restored without losing a recoverable local generation.
- Security: user A cannot read/write user B's row; no service-role key in APK or source.
