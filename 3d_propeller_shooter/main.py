# pip install ursina
from ursina import *
import random
import math

# ==========================================
# 1950년대 풍 3D 프로펠러 비행 슈팅 게임 (개선판)
# ==========================================

app = Ursina()

# 기본 설정
window.title = '1950s Propeller Shooter - Advanced'
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

# 땅(바닥) 추가 (현실감 부여)
ground = Entity(model='plane', texture='grass', scale=2000, position=(0,-50,0), collider='mesh', tiling=(20,20))
# 바다/물 레이어 (멀리서 보일 용도)
water = Entity(model='plane', color=color.azure, scale=5000, position=(0,-55,0))

# 전역 변수
score = 0
score_text = Text(text=f'Score: {score}', position=(-0.85, 0.40), scale=2, color=color.yellow)

# UI 요소: 레이더 (좌측 하단)
radar_base = Entity(parent=camera.ui, model='circle', color=color.black66, scale=0.2, position=(-0.7, -0.35))
radar_scan = Entity(parent=radar_base, model='circle', color=color.green, scale=0.05) # 플레이어 표시

# UI 요소: 나침반 (좌측 상단)
compass_base = Entity(parent=camera.ui, model='circle', color=color.black66, scale=0.15, position=(-0.7, 0.3))
compass_arrow = Entity(parent=compass_base, model='arrow', color=color.red, scale=0.6, rotation_z=0)
Text(parent=compass_base, text='N', position=(0, 0.6), origin=(0,0), scale=5)

# 플레이어 비행기 클래스
class Player(Entity):
    def __init__(self):
        super().__init__(
            model='cube',
            color=color.light_gray,
            scale=(1, 0.8, 4), # 동체 길게
            collider='box'
        )

        # --- 정교한 비행기 모델링 ---
        # 콕핏
        self.cockpit = Entity(parent=self, model='sphere', color=color.cyan, scale=(0.6, 0.5, 0.3), position=(0, 0.4, 0.2))
        # 날개 (주익)
        self.wings = Entity(parent=self, model='cube', color=color.gray, scale=(5, 0.1, 1.2), position=(0, 0, 0.5))
        # 수평 꼬리날개
        self.tail_h = Entity(parent=self, model='cube', color=color.gray, scale=(2, 0.1, 0.6), position=(0, 0, -1.6))
        # 수직 꼬리날개
        self.tail_v = Entity(parent=self, model='cube', color=color.gray, scale=(0.1, 1, 0.6), position=(0, 0.5, -1.6))

        # 기관총 (날개에 장착)
        self.gun_l = Entity(parent=self, model='cylinder', color=color.black, scale=(0.05, 0.8, 0.05), position=(-1, 0, 1), rotation_x=90)
        self.gun_r = Entity(parent=self, model='cylinder', color=color.black, scale=(0.05, 0.8, 0.05), position=(1, 0, 1), rotation_x=90)

        # 프로펠러
        self.prop_hub = Entity(parent=self, model='sphere', color=color.dark_gray, scale=(0.3, 0.3, 0.2), position=(0, 0, 2))
        self.propeller = Entity(parent=self, model='cube', color=color.black, scale=(3, 0.1, 0.05), position=(0, 0, 2.1))

        self.speed = 25
        self.boost_speed = 50
        self.rotation_speed = 100

        # 사격 설정
        self.shoot_cooldown = 0.12
        self.timer = 0
        self.gun_side = 0 # 0: 좌측, 1: 우측 번갈아 사격

        # 카메라 설정
        camera.parent = self
        camera.position = (0, 4, -12)
        camera.rotation_x = 12

        # 타겟 포인터 (적 추적 화살표 - UI)
        self.pointer = Entity(parent=camera.ui, model='arrow', color=color.orange, scale=0.05, position=(0, 0.2))
        self.target_dist_text = Text(parent=camera.ui, text='', position=(0, 0.15), origin=(0,0), scale=1, color=color.orange)

        # 3D 추적기 (플레이어 기체 근처에서 적을 가리키는 화살표)
        self.tracker_3d = Entity(parent=self, model='arrow', color=color.yellow, scale=0.5, position=(0, 1.5, 2))

        mouse.locked = True

    def update(self):
        # 가장 가까운 적 찾기
        nearest_enemy = None
        min_dist = float('inf')
        for e in enemies:
            if e and not e.enabled: continue # 이미 파괴된 경우 제외
            d = (e.world_position - self.world_position).length()
            if d < min_dist:
                min_dist = d
                nearest_enemy = e

        if nearest_enemy:
            # 화면 중앙에서 적 방향으로 화살표 회전
            # 템플릿 엔티티를 사용하여 월드 좌표를 스크린 좌표로 변환
            _temp = Entity(position=nearest_enemy.world_position, add_to_scene_entities=False)
            p_pos = _temp.screen_position
            destroy(_temp)

            angle = math.degrees(math.atan2(p_pos.x, p_pos.y))
            self.pointer.rotation_z = -angle
            self.pointer.enabled = True
            self.target_dist_text.text = f"{int(min_dist)}m"

            # 3D 추적기가 적을 바라보게 설정
            self.tracker_3d.look_at(nearest_enemy)
            self.tracker_3d.enabled = True
        else:
            self.pointer.enabled = False
            self.target_dist_text.text = ""
            self.tracker_3d.enabled = False

        # 프로펠러 회전
        self.propeller.rotation_z += 1200 * time.dt

        # 조작 (Pitch, Yaw, Roll)
        self.rotation_x -= mouse.velocity[1] * self.rotation_speed
        self.rotation_y += mouse.velocity[0] * self.rotation_speed

        # 비행기 기울기에 따른 Roll 효과
        target_roll = -mouse.velocity[0] * self.rotation_speed * 0.6
        self.rotation_z = lerp(self.rotation_z, target_roll, time.dt * 4)

        # 이동
        current_speed = self.boost_speed if held_keys['w'] else self.speed
        self.position += self.forward * current_speed * time.dt

        # 사격 (마우스 좌클릭)
        self.timer += time.dt
        if mouse.left and self.timer >= self.shoot_cooldown:
            self.shoot()
            self.timer = 0

        # 나침반 업데이트
        compass_arrow.rotation_z = -self.rotation_y

    def shoot(self):
        # 번갈아가며 사격
        pos = self.gun_l.world_position if self.gun_side == 0 else self.gun_r.world_position
        Bullet(position=pos, rotation=self.rotation)
        self.gun_side = 1 - self.gun_side

# 탄환 클래스
class Bullet(Entity):
    def __init__(self, **kwargs):
        super().__init__(
            model='cube', # 실린더 대신 큐브를 길게 늘려 트레이서 느낌 구현 (회전 제어 용이)
            color=color.yellow,
            scale=(0.1, 0.1, 2.0),
            collider='box',
            **kwargs
        )
        self.speed = 250
        self.lifetime = 1.5

    def update(self):
        self.position += self.forward * self.speed * time.dt
        self.lifetime -= time.dt

        hit_info = self.intersects()
        if hit_info.hit:
            if isinstance(hit_info.entity, Enemy):
                hit_info.entity.destroy_enemy()
                destroy(self)
                return

        if self.lifetime <= 0:
            destroy(self)

# 적 비행체 클래스
class Enemy(Entity):
    def __init__(self, position):
        super().__init__(
            model='cube',
            color=color.red,
            scale=(1, 0.7, 3.5),
            position=position,
            collider='box'
        )
        # 적 모델링
        Entity(parent=self, model='cube', color=color.brown, scale=(4, 0.1, 1), position=(0,0,0.3)) # 날개
        Entity(parent=self, model='cube', color=color.brown, scale=(0.1, 0.8, 0.5), position=(0,0.4,-1.4)) # 꼬리

        # HUD 마커 (내장 텍스처 circle 사용)
        self.marker = Entity(model='quad', texture='circle', color=color.red, scale=1.5, billboard=True)
        # 마커 테두리 효과를 위해 하나 더 겹침
        self.marker_inner = Entity(parent=self.marker, model='quad', texture='circle', color=color.white, scale=0.8, position=(0,0,-0.1))

        # 레이더 점
        self.radar_dot = Entity(parent=radar_base, model='circle', color=color.red, scale=0.08)

        self.speed = random.uniform(15, 25)
        self.target_timer = 0
        self.move_dir = Vec3(random.uniform(-1,1), random.uniform(-0.2, 0.2), random.uniform(-1,1)).normalized()

    def update(self):
        # 실감나는 비행: 플레이어 쪽으로 서서히 방향을 틀거나 불규칙하게 이동
        self.target_timer += time.dt
        if self.target_timer > 3:
            # 3초마다 새로운 방향 설정 (플레이어 근처로)
            to_player = (player.position - self.position).normalized()
            self.move_dir = (to_player + Vec3(random.uniform(-0.5,0.5), random.uniform(-0.2,0.2), random.uniform(-0.5,0.5))).normalized()
            self.target_timer = 0

        # 부드러운 회전 및 이동
        self.look_at(self.position + self.move_dir)
        self.position += self.forward * self.speed * time.dt

        # 마커 및 레이더 업데이트
        self.marker.position = self.position

        # 레이더 좌표 계산 (2D 투영)
        rel_pos = self.position - player.position
        dist = rel_pos.length()
        if dist < 300: # 레이더 범위 내
            radar_x = rel_pos.x / 300
            radar_y = rel_pos.z / 300
            # 플레이어의 회전에 맞춰 레이더 점 회전
            angle = math.radians(player.rotation_y)
            rx = radar_x * math.cos(angle) - radar_y * math.sin(angle)
            ry = radar_x * math.sin(angle) + radar_y * math.cos(angle)
            self.radar_dot.enabled = True
            self.radar_dot.position = (rx, ry)
        else:
            self.radar_dot.enabled = False

    def destroy_enemy(self):
        global score
        score += 100
        score_text.text = f'Score: {score}'

        # 실감나는 폭발: 연기 및 화염 파티클
        for _ in range(25):
            particle = Entity(
                model='sphere',
                color=random.choice([color.orange, color.yellow, color.red, color.gray]),
                position=self.position + Vec3(random.uniform(-1,1), random.uniform(-1,1), random.uniform(-1,1)),
                scale=random.uniform(0.3, 1.2)
            )
            # 사방으로 튀어나감
            dest = particle.position + Vec3(random.uniform(-8,8), random.uniform(-8,8), random.uniform(-8,8))
            particle.animate_position(dest, duration=0.6, curve=curve.out_expo)
            particle.animate_scale(0, duration=0.6)
            destroy(particle, delay=0.6)

        # 물리 파편 효과 (큐브 파편)
        for _ in range(8):
            debris = Entity(
                model='cube',
                color=color.brown,
                position=self.position,
                scale=random.uniform(0.2, 0.5),
                rotation=(random.randint(0,360), random.randint(0,360), random.randint(0,360))
            )
            dest = debris.position + Vec3(random.uniform(-10,10), random.uniform(-15,5), random.uniform(-10,10))
            debris.animate_position(dest, duration=1.0, curve=curve.out_circ)
            debris.animate_rotation((720, 720, 720), duration=1.0)
            debris.fade_out(duration=1.0)
            destroy(debris, delay=1.0)

        # 중앙 거대 섬광
        explode = Entity(model='sphere', color=color.yellow, position=self.position, scale=1)
        explode.animate_scale(12, duration=0.3, curve=curve.out_expo)
        explode.fade_out(duration=0.3)
        destroy(explode, delay=0.3)

        destroy(self.marker)
        # self.marker_inner는 marker의 자식이므로 함께 삭제됨
        destroy(self.radar_dot)
        destroy(self)

# 배경 변경 시스템
bg_types = [
    {'name': 'Day', 'sky': color.azure, 'sun': color.white},
    {'name': 'Dusk', 'sky': color.orange, 'sun': color.orange},
    {'name': 'Night', 'sky': color.black, 'sun': color.dark_gray},
    {'name': 'Foggy', 'sky': color.light_gray, 'sun': color.white}
]
current_bg = 0

def change_background():
    global current_bg
    current_bg = (current_bg + 1) % len(bg_types)
    bg = bg_types[current_bg]
    sky.color = bg['sky']
    sun.color = bg['sun']
    scene.fog_color = bg['sky']
    scene.fog_density = (0.002, 0.005) if bg['name'] == 'Foggy' else 0
    print(f"Background changed to: {bg['name']}")

# 적 스폰
enemies = []
def spawn_enemy():
    dist = 300
    angle = random.uniform(0, math.pi * 2)
    x = player.x + math.cos(angle) * dist
    y = player.y + random.uniform(-30, 30)
    z = player.z + math.sin(angle) * dist
    enemies.append(Enemy(position=(x, y, z)))
    invoke(spawn_enemy, delay=4)

player = Player()

# 초기 적
for _ in range(8):
    pos = (random.uniform(-150, 150), random.uniform(-20, 50), random.uniform(50, 250))
    enemies.append(Enemy(position=pos))

spawn_enemy()

# 게임 설명서 및 설정 버튼 (톱니바퀴)
help_panel = WindowPanel(
    title='게임 설명서 (Manual)',
    content=(
        Text('조작 방법:'),
        Text('- 마우스: 비행기 회전 (Pitch/Yaw)'),
        Text('- 왼쪽 클릭: 기관총 사격'),
        Text('- W 키: 부스트 가속'),
        Text('- B 키: 배경 테마 변경'),
        Text('- ESC 키: 게임 종료'),
        Text(''),
        Text('목표: 적 비행기를 격추하여 점수를 획득하세요!'),
        Button(text='닫기', color=color.azure, on_click=lambda: setattr(help_panel, 'enabled', False))
    ),
    enabled=False,
    popup=True
)

gear_button = Button(
    text='⚙',
    color=color.black66,
    scale=0.05,
    position=(0.85, 0.45),
    on_click=lambda: setattr(help_panel, 'enabled', not help_panel.enabled)
)

def input(key):
    if key == 'escape':
        quit()
    if key == 'b': # 배경 변경 단축키
        change_background()
    if key == 'h': # 도움말 단축키
        help_panel.enabled = not help_panel.enabled

print("-" * 50)
print("1950s Propeller Shooter 구동 중...")
print("화면 우측 상단의 톱니바퀴 버튼을 눌러 설명서를 확인할 수 있습니다.")
print("-" * 50)

app.run()
