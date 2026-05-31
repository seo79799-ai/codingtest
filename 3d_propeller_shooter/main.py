# pip install ursina
from ursina import *
import random
import math

# ==========================================
# 1950년대 풍 3D 프로펠러 비행 슈팅 게임 (복구 및 개선판)
# ==========================================

app = Ursina()

# 기본 설정
window.title = '1950s Propeller Shooter - Fixed'
window.borderless = False
window.fullscreen = False
window.exit_button.visible = False
window.fps_counter.enabled = True

# 카메라 및 배경 설정
sky = Sky()
camera.orthographic = False
camera.fov = 60

# 광원 추가
sun = DirectionalLight()
sun.look_at(Vec3(1,-1,-1))

# 땅(바닥) 및 구름 추가
ground = Entity(model='plane', texture='grass', scale=2000, position=(0,-50,0), collider='mesh', tiling=(40,40))
water = Entity(model='plane', color=color.azure, scale=5000, position=(0,-55,0))
clouds = []
for _ in range(30):
    clouds.append(Entity(model='sphere', color=color.white, alpha=0.6, scale=(random.uniform(20, 50), random.uniform(5, 15), random.uniform(20, 40)), position=(random.uniform(-500, 500), random.uniform(100, 200), random.uniform(-500, 1000))))

# ---------------------------------------------------------
# 1. 다국어 시스템 및 상태 관리
# ---------------------------------------------------------
translations = {
    'en': {
        'start_title': 'Flight Manual', 'start_msg': 'Ready to fly?', 'yes': 'START (YES)',
        'score': 'Score', 'enemies': 'Enemies', 'timer': 'Time Left', 'call_enemy': 'Press SPACE to call the enemy!',
        'win': 'Mission Accomplished! (R to Reset)', 'lose': 'Time Over! (R to Reset)', 'paused': 'PAUSED',
        'manual_title': 'Game Manual', 'controls': 'Controls:', 'mouse': '- Mouse: Rotate / Click: Fire',
        'space': '- SPACE: Call / R: Reset', 'pause_key': '- P: Pause', 'diff_key': '- 1~0: Level',
        'bg_key': '- B: Sky / ESC: Quit', 'rules': 'Rules:', 'rule1': '- Kill enemy within 60s.',
        'diff_select': 'Level Select', 'close': 'Close'
    },
    'ko': {
        'start_title': '비행 지침서', 'start_msg': '비행을 시작하시겠습니까?', 'yes': '비행 시작 (YES)',
        'score': '점수', 'enemies': '적기', 'timer': '남은 시간', 'call_enemy': 'SPACE 키를 눌러 적기를 호출하세요!',
        'win': '임무 완수! (R 키로 재도전)', 'lose': '시간 초과! (R 키로 재도전)', 'paused': '일시정지',
        'manual_title': '게임 설명서', 'controls': '조작 방법:', 'mouse': '- 마우스: 회전 / 클릭: 사격',
        'space': '- SPACE: 호출 / R: 초기화', 'pause_key': '- P: 일시정지', 'diff_key': '- 숫자키: 난이도',
        'bg_key': '- B: 배경 / ESC: 종료', 'rules': '규칙:', 'rule1': '- 60초 내 격추.',
        'diff_select': '난이도 선택', 'close': '닫기'
    }
}

current_lang = 'en'
def load_language():
    global current_lang
    try:
        with open('lang_settings.txt', 'r') as f:
            l = f.read().strip()
            if l in translations: current_lang = l
    except: current_lang = 'en'

def save_language(l):
    global current_lang
    current_lang = l
    with open('lang_settings.txt', 'w') as f: f.write(l)
    update_ui_text()

load_language()

# ---------------------------------------------------------
# 2. UI 요소 미리 정의
# ---------------------------------------------------------
score = 0
difficulty = 1
game_state = 'MENU'
timer = 60

score_text = Text(text='', position=(-0.85, 0.40), scale=2, color=color.yellow)
enemy_count_text = Text(text='', position=(0, 0.45), origin=(0,0), scale=2, color=color.red)
timer_text = Text(text='', position=(0, 0.4), origin=(0,0), scale=2, color=color.white)
status_message = Text(text='', position=(0, 0.1), origin=(0,0), scale=2, color=color.yellow)
diff_text = Text(text='', position=(0.85, 0.40), scale=1.5, color=color.lime)
pause_text = Text(parent=camera.ui, text='PAUSED', origin=(0,0), scale=3, color=color.yellow, enabled=False)

radar_base = Entity(parent=camera.ui, model='circle', color=color.black66, scale=0.2, position=(-0.7, -0.35))
radar_scan = Entity(parent=radar_base, model='circle', color=color.green, scale=0.05)
compass_base = Entity(parent=camera.ui, model='circle', color=color.black66, scale=0.15, position=(-0.7, 0.3))
compass_arrow = Entity(parent=compass_base, model='arrow', color=color.red, scale=0.6)
Text(parent=compass_base, text='N', position=(0, 0.6), origin=(0,0), scale=5)

diff_buttons = []
enemies = []

# ---------------------------------------------------------
# 3. 클래스 및 비행기 모델 (안정적 버전)
# ---------------------------------------------------------
class Player(Entity):
    def __init__(self):
        super().__init__(model='cube', color=color.light_gray, scale=(1, 0.8, 4), collider='box')
        Entity(parent=self, model='sphere', color=color.cyan, scale=(0.6, 0.5, 0.3), position=(0, 0.4, 0.2)) # cockpit
        self.wings = Entity(parent=self, model='cube', color=color.gray, scale=(5, 0.1, 1.2), position=(0, 0, 0.5))
        Entity(parent=self, model='cube', color=color.gray, scale=(2, 0.1, 0.6), position=(0, 0, -1.6)) # tail_h
        Entity(parent=self, model='cube', color=color.gray, scale=(0.1, 1, 0.6), position=(0, 0.5, -1.6)) # tail_v
        self.gun_l = Entity(parent=self, model='cylinder', color=color.black, scale=(0.05, 0.8, 0.05), position=(-1, 0, 1), rotation_x=90)
        self.gun_r = Entity(parent=self, model='cylinder', color=color.black, scale=(0.05, 0.8, 0.05), position=(1, 0, 1), rotation_x=90)
        self.propeller = Entity(parent=self, model='cube', color=color.black, scale=(3, 0.1, 0.05), position=(0, 0, 2.1))

        self.speed, self.boost_speed, self.rotation_speed = 25, 50, 100
        self.shoot_cooldown, self.timer, self.gun_side = 0.05, 0, 0

        camera.parent = self
        camera.position, camera.rotation_x = (0, 4, -12), 12

        # UI/Reticle
        self.reticle_circle = Entity(parent=camera.ui, model='circle', color=color.red, scale=0.12, mode='line', thickness=3)
        self.reticle_dot = Entity(parent=camera.ui, model='circle', color=color.black, scale=0.005)
        self.pointer = Entity(parent=camera.ui, model='arrow', color=color.orange, scale=0.08, position=(0, 0.35))
        self.target_dist_text = Text(parent=camera.ui, text='', position=(0, 0.3), origin=(0,0), scale=1.5, color=color.orange)
        self.tracker_3d = Entity(parent=self, model='arrow', color=color.yellow, scale=0.5, position=(0, 1.5, 2))

    def update(self):
        global game_state, timer
        if game_state == 'MENU': return
        t_lib = translations[current_lang]

        if game_state == 'PLAYING':
            timer -= time.dt
            timer_text.text = f"{t_lib['timer']}: {int(timer)}s"
            if timer <= 0:
                game_state = 'LOSE'; update_ui_text()
                for e in enemies:
                    if e and e.enabled: destroy(e.marker); destroy(e.radar_dot); destroy(e)

        active_enemies = [e for e in enemies if e and e.enabled]
        enemy_count_text.text = f"{t_lib['enemies']}: {len(active_enemies)}"
        if game_state == 'PLAYING' and not active_enemies:
            game_state = 'WIN'; update_ui_text()

        nearest_enemy = None
        min_dist = float('inf')
        for e in active_enemies:
            d = (e.world_position - self.world_position).length()
            if d < min_dist: min_dist = d; nearest_enemy = e

        if nearest_enemy:
            _temp = Entity(position=nearest_enemy.world_position, add_to_scene_entities=False)
            p_pos = _temp.screen_position; destroy(_temp)
            self.pointer.rotation_z = -math.degrees(math.atan2(p_pos.x, p_pos.y))
            self.pointer.enabled = True
            self.target_dist_text.text = f"{int(min_dist)}m"
            self.tracker_3d.look_at(nearest_enemy)
            self.tracker_3d.enabled = True
        else:
            self.pointer.enabled = self.tracker_3d.enabled = False
            self.target_dist_text.text = ""

        self.propeller.rotation_z += 1200 * time.dt
        self.rotation_x -= mouse.velocity[1] * self.rotation_speed
        self.rotation_y += mouse.velocity[0] * self.rotation_speed
        self.rotation_z = lerp(self.rotation_z, -mouse.velocity[0] * self.rotation_speed * 0.6, time.dt * 4)
        self.position += self.forward * (self.boost_speed if held_keys['w'] else self.speed) * time.dt

        self.timer += time.dt
        if mouse.left and self.timer >= self.shoot_cooldown:
            Bullet(position=(self.gun_l.world_position if self.gun_side == 0 else self.gun_r.world_position), rotation=self.rotation)
            self.gun_side = 1 - self.gun_side; self.timer = 0
        compass_arrow.rotation_z = -self.rotation_y

class Enemy(Entity):
    def __init__(self, position):
        super().__init__(model='cube', color=color.red, scale=(1, 0.7, 3.5), position=position, collider='box')
        Entity(parent=self, model='cube', color=color.brown, scale=(4, 0.1, 1), position=(0,0,0.3))
        Entity(parent=self, model='cube', color=color.brown, scale=(0.1, 0.8, 0.5), position=(0,0.4,-1.4))
        self.marker = Entity(model='quad', texture='circle', color=color.red, scale=1.5, billboard=True)
        self.marker_inner = Entity(parent=self.marker, model='quad', texture='circle', color=color.white, scale=0.8, position=(0,0,-0.1))
        self.radar_dot = Entity(parent=radar_base, model='circle', color=color.red, scale=0.08)
        self.evade_timer, self.offset = 0, Vec3(0,0,0)

    def update(self):
        global difficulty
        self.evade_timer += time.dt
        if self.evade_timer > max(0.1, 1.5 - (difficulty * 0.14)):
            evade_range = difficulty * 3.5
            self.offset = Vec3(random.uniform(-evade_range, evade_range), random.uniform(-evade_range * 0.7, evade_range * 0.7), 0)
            self.evade_timer = 0
        self.position = lerp(self.position, player.position + player.forward * 70 + player.right * self.offset.x + player.up * self.offset.y, time.dt * 3)
        self.look_at(self.position + player.forward); self.marker.position = self.position
        rel_pos = self.position - player.position
        if rel_pos.length() < 300:
            radar_x, radar_y = rel_pos.x / 300, rel_pos.z / 300
            angle = math.radians(player.rotation_y)
            rx = radar_x * math.cos(angle) - radar_y * math.sin(angle)
            ry = radar_x * math.sin(angle) + radar_y * math.cos(angle)
            self.radar_dot.enabled = True; self.radar_dot.position = (rx, ry)
        else: self.radar_dot.enabled = False

    def destroy_enemy(self):
        global score; score += 100; update_ui_text()
        for _ in range(15):
            p = Entity(model='sphere', color=random.choice([color.orange, color.yellow, color.red]), position=self.position, scale=random.uniform(0.3, 1.2))
            p.animate_position(p.position + Vec3(random.uniform(-8,8), random.uniform(-8,8), random.uniform(-8,8)), duration=0.6)
            p.animate_scale(0, duration=0.6); destroy(p, delay=0.6)
        destroy(self.marker); destroy(self.radar_dot); destroy(self)

class Bullet(Entity):
    def __init__(self, **kwargs):
        super().__init__(model='cube', color=color.yellow, scale=(0.1, 0.1, 3.0), collider='box', **kwargs)
        self.speed = 400; self.lifetime = 1.2
    def update(self):
        self.position += self.forward * self.speed * time.dt
        self.lifetime -= time.dt
        hit_info = self.intersects()
        if hit_info.hit and isinstance(hit_info.entity, Enemy):
            hit_info.entity.destroy_enemy(); destroy(self)
        elif self.lifetime <= 0: destroy(self)

# ---------------------------------------------------------
# 4. 기능 함수 (UI 갱신, 난이도, 언어)
# ---------------------------------------------------------
def update_ui_text():
    t = translations[current_lang]
    score_text.text = f"{t['score']}: {score}"
    enemy_count_text.text = f"{t['enemies']}: {len([e for e in enemies if e and e.enabled])}"
    diff_text.text = f"{t['diff_select']}: {difficulty}"
    if game_state == 'WAITING': status_message.text = t['call_enemy']
    elif game_state == 'WIN': status_message.text = t['win']
    elif game_state == 'LOSE': status_message.text = t['lose']
    else: status_message.text = ''
    pause_text.text = t['paused']
    for i, btn in enumerate(diff_buttons): btn.color = color.orange if i+1 == difficulty else color.black66
    if 'help_panel' in globals() and help_panel.enabled: create_help_panel(); help_panel.enabled = True
    if 'start_panel' in globals() and start_panel.enabled: create_start_panel(); start_panel.enabled = True

def set_difficulty(val):
    global difficulty; difficulty = clamp(val, 1, 10); update_ui_text()

def toggle_pause():
    if game_state == 'MENU': return
    application.paused = not application.paused; pause_text.enabled = application.paused; mouse.locked = not application.paused

def request_enemy():
    global game_state, timer
    if game_state in ['WAITING', 'WIN', 'LOSE']:
        for e in enemies:
            if e and e.enabled: destroy(e.marker); destroy(e.radar_dot); destroy(e)
        enemies.clear(); game_state = 'PLAYING'; timer = 60; enemies.append(Enemy(position=player.position + player.forward * 60)); update_ui_text()

def reset_game():
    global game_state, timer, score; game_state = 'WAITING'; timer = 60; score = 0
    for e in enemies:
        if e and e.enabled: destroy(e.marker); destroy(e.radar_dot); destroy(e)
    enemies.clear(); update_ui_text(); timer_text.text = ''

def start_game():
    global game_state; game_state = 'WAITING'; start_panel.enabled = False; player.enabled = True; mouse.locked = True; update_ui_text()

# ---------------------------------------------------------
# 5. 패널 생성 함수
# ---------------------------------------------------------
def create_help_panel():
    global help_panel
    t = translations[current_lang]
    if 'help_panel' in globals(): destroy(help_panel)
    help_panel = WindowPanel(title=t['manual_title'], content=(
        Text(t['controls']), Text(t['mouse']), Text(t['space']), Text(t['pause_key']), Text(t['diff_key']), Text(t['bg_key']),
        Text(''), Text(t['rules']), Text(t['rule1']), Text(''),
        Text('Language / 언어:'), ButtonGroup(('English', '한국어'), on_selection_changed=lambda i: save_language('en' if i==0 else 'ko')),
        Text(''), Text(t['diff_select'] + ':'), ButtonGroup(('1','2','3','4','5','6','7','8','9','10'), on_selection_changed=lambda i: set_difficulty(i+1)),
        Button(text=t['close'], color=color.azure, on_click=lambda: setattr(help_panel, 'enabled', False))
    ), enabled=False, popup=True)

def create_start_panel():
    global start_panel
    t = translations[current_lang]
    if 'start_panel' in globals(): destroy(start_panel)
    start_panel = WindowPanel(title=t['start_title'], content=(
        Text(t['start_msg'], origin=(0,0)), Text(''),
        Text(t['controls']), Text(t['mouse']), Text(t['space']),
        Text(''), Text('Language / 언어:'),
        ButtonGroup(('English', '한국어'), on_selection_changed=lambda i: [save_language('en' if i==0 else 'ko'), create_start_panel()]),
        Text(''), Button(text=t['yes'], color=color.green, on_click=start_game)
    ), enabled=True, popup=True)

# ---------------------------------------------------------
# 6. 초기화 및 버튼 배치
# ---------------------------------------------------------
pause_button = Button(text='||', color=color.black66, scale=0.05, position=(0.78, 0.45), on_click=toggle_pause)
gear_button = Button(text='⚙', color=color.black66, scale=0.05, position=(0.85, 0.45), on_click=lambda: setattr(help_panel, 'enabled', not help_panel.enabled))
for i in range(1, 11):
    diff_buttons.append(Button(text=str(i), parent=camera.ui, scale=(0.03, 0.03), position=(0.85, 0.35 - (i * 0.04)), color=color.black66, highlight_color=color.lime, on_click=Func(set_difficulty, i)))

player = Player(); player.enabled = False
create_help_panel(); create_start_panel(); update_ui_text(); mouse.locked = False

bg_types = [{'sky': color.azure, 'sun': color.white}, {'sky': color.orange, 'sun': color.orange}, {'sky': color.black, 'sun': color.dark_gray}, {'sky': color.light_gray, 'sun': color.white}]
current_bg = 0
def change_background():
    global current_bg; current_bg = (current_bg + 1) % len(bg_types)
    bg = bg_types[current_bg]; sky.color = sun.color = scene.fog_color = bg['sky']
    scene.fog_density = (0.002, 0.005) if current_bg == 3 else 0

def input(key):
    if key == 'escape': quit()
    if key == 'p': toggle_pause()
    if key == 'b': change_background()
    if key == 'h': help_panel.enabled = not help_panel.enabled
    if key == 'space': request_enemy()
    if key == 'r': reset_game()
    if key in ['1','2','3','4','5','6','7','8','9','0']: set_difficulty(10 if key == '0' else int(key))

app.run()
