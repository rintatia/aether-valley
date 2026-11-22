from pathlib import Path
import json, re, sys
ROOT = Path(__file__).resolve().parents[1]
errors=[]
def check(condition, message):
    if not condition: errors.append(message)
project=(ROOT/'project.godot').read_text()
scene=(ROOT/'scenes/main.tscn').read_text()
player=(ROOT/'scripts/player.gd').read_text()
save=(ROOT/'scripts/save_service.gd').read_text()
touch=(ROOT/'scripts/touch_controls.gd').read_text()
world=(ROOT/'scripts/world.gd').read_text()
seasons=json.loads((ROOT/'data/seasons.json').read_text())
check('config/name="Aether Valley"' in project, 'Project display name mismatch')
check('run/main_scene="res://scenes/main.tscn"' in project, 'Main scene missing')
check('SaveService="*res://scripts/save_service.gd"' in project, 'SaveService autoload missing')
for path in re.findall(r'path="(res://[^"]+)"', scene):
    check((ROOT/path.removeprefix('res://')).exists(), f'Missing scene resource: {path}')
check('Input.get_vector("move_left", "move_right", "move_up", "move_down")' in player, '8-way input vector missing')
check('move_and_slide()' in player, 'CharacterBody2D movement call missing')
check('AUTOSAVE_INTERVAL_SECONDS := 30.0' in save, 'Local autosave interval must be 30 seconds')
check('NOTIFICATION_APPLICATION_PAUSED' in save and 'NOTIFICATION_WM_CLOSE_REQUEST' in save, 'Lifecycle save hooks missing')
check('BACKUP_PATH' in save and 'PREVIOUS_BACKUP_PATH' in save, 'Backup recovery rotation missing')
check('var previous_backup := _read_payload(PREVIOUS_BACKUP_PATH)' in save, 'Older backup recovery fallback missing')
check('if not (payload is Dictionary):' in save, 'Save payload type validation missing')
check('JSON.parse_string' in save and 'schema_version' in save, 'Versioned JSON validation missing')
check('Input.action_press(action)' in touch and 'Input.action_release(action)' in touch, 'Touch input press/release missing')
check('overlay.resized.connect(_layout_buttons)' in touch, 'Touch controls are not responsive to viewport resize')
check(len(seasons)==14, f'Expected 14 approved seasons, got {len(seasons)}')
check(len({s['id'] for s in seasons})==len(seasons), 'Season IDs are not unique')
check('season_names[season_id]' in world, 'Season catalog is not loaded into runtime')
check('func _screen_to_grid(screen: Vector2) -> Vector2:' in world, 'Ground grid inverse projection missing')
check('queue_redraw()' in world and '_last_grid_center' in world, 'Ground grid does not refresh around the moving player')
check('GRID_ORIGIN + _grid_to_screen' in world, 'Ground grid lattice origin is not stable')
for p in [ROOT/'project.godot', *ROOT.glob('scripts/*.gd'), *ROOT.glob('scenes/*.tscn'), *ROOT.glob('data/*')]:
    content=p.read_text(errors='ignore').lower()
    check('aetherfield' not in content and 'everworld' not in content, f'Legacy branding found in {p.relative_to(ROOT)}')
if errors:
    print('STATIC AUDIT: FAIL')
    print('\n'.join('- '+e for e in errors))
    sys.exit(1)
print('STATIC AUDIT: PASS')
print(f'Checked {len(seasons)} seasons, scene resource paths, input/movement hooks, local autosave/backup hooks, touch controls, project branding.')
print('LIMIT: This is not a Godot parser, runtime, Android export, or physical-device test.')
