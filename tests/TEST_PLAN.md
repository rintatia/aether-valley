# Required validation before APK release

1. Godot 4.x editor import and parse; capture full log and exit code.
2. Headless project launch and automated GDScript tests.
3. Projection round-trip tests and all eight movement directions.
4. Collision and obstacle sliding; no tunnelling at low frame rate.
5. Desktop smoke test: launch, movement, camera, HUD, save/restart/load.
6. Save fault tests: corrupt primary, backup restore, interrupted temp write, missing save, schema mismatch.
7. Android ARM64 debug export; verify package id, version, signature, permissions, landscape/immersive layout.
8. Physical device install/launch; touch controls, rotation, pause/resume, save/restore, display fit.
9. Re-test all fixes. A passing source inspection is not a runtime pass.
