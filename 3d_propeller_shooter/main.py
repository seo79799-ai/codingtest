# pip install ursina
from ursina import *
import random

# ==========================================
# 1950년대 풍 3D 프로펠러 비행 슈팅 게임
# ==========================================

app = Ursina()

# 기본 설정
window.title = '1950s Propeller Shooter'
window.borderless = False
window.fullscreen = False
window.exit_button.visible = False
window.fps_counter.enabled = True

# 카메라 및 배경 설정
Sky()
camera.orthographic = False
camera.fov = 60

# 전역 변수
score = 0
score_text = Text(text=f'Score: {score}', position=(-0.85, 0.45), scale=2, color=color.yellow)

# 플레이어 비행기 클래스
class Player(Entity):
    def __init__(self):
        super().__init__(
            model='cube',
            color=color.light_gray,
            scale=(1.2, 0.8, 3),
            collider='box'
        )

        # 날개 구현 (내장 프리미티브 사용)
        self.wings = Entity(parent=self, model='cube', color=color.gray, scale=(4.5, 0.1, 0.8), position=(0, 0, 0.2))
        self.tail_fin = Entity(parent=self, model='cube', color=color.gray, scale=(0.1, 1.2, 0.6), position=(0, 0.5, -1.2))

        # 프로펠러 구현
        self.propeller = Entity(parent=self, model='cube', color=color.black, scale=(2.5, 0.1, 0.1), position=(0, 0, 1.5))

        self.speed = 20
        self.boost_speed = 40
        self.rotation_speed = 100

        # 사격 쿨타임 설정
        self.shoot_cooldown = 0.1
        self.timer = 0

        # 카메라를 플레이어 자식으로 설정 (3인칭 백뷰)
        camera.parent = self
        camera.position = (0, 3, -10)
        camera.rotation_x = 10

        mouse.locked = True

    def update(self):
        # 프로펠러 회전
        self.propeller.rotation_z += 1000 * time.dt

        # 마우스 조작 (Pitch, Yaw, Roll)
        self.rotation_x -= mouse.velocity[1] * self.rotation_speed
        self.rotation_y += mouse.velocity[0] * self.rotation_speed

        # 자연스러운 Roll 효과
        target_roll = -mouse.velocity[0] * self.rotation_speed * 0.5
        self.rotation_z = lerp(self.rotation_z, target_roll, time.dt * 5)

        # 전진 이동
        current_speed = self.boost_speed if held_keys['w'] else self.speed
        self.position += self.forward * current_speed * time.dt

        # 사격 처리 (쿨타임 적용)
        self.timer += time.dt
        if mouse.left and self.timer >= self.shoot_cooldown:
            self.shoot()
            self.timer = 0

    def shoot(self):
        # 기관총 발사 (탄환 엔티티 생성)
        # 좌우 총구에서 번갈아 나가는 느낌을 위해 약간의 offset 추가 가능 (여기서는 중앙 발사)
        bullet = Bullet(position=self.position + self.forward * 2, rotation=self.rotation)

# 탄환 클래스
class Bullet(Entity):
    def __init__(self, **kwargs):
        super().__init__(
            model='sphere',
            color=color.yellow,
            scale=0.2,
            collider='sphere',
            **kwargs
        )
        self.speed = 150
        self.lifetime = 2.0

    def update(self):
        self.position += self.forward * self.speed * time.dt
        self.lifetime -= time.dt

        # 충돌 판정
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
            scale=(2, 1, 2.5),
            position=position,
            collider='box'
        )
        # 적 날개
        Entity(parent=self, model='cube', color=color.dark_gray, scale=(4, 0.1, 0.6))

        # HUD 타겟 마커 (가시성 확보)
        self.marker = Entity(
            model='quad',
            texture='circle_outlined',
            color=color.red,
            scale=3,
            billboard=True,
            double_sided=True
        )

    def update(self):
        # 플레이어 근처로 아주 느리게 이동하거나 배회하도록 설정 가능
        self.rotation_y += 10 * time.dt

        # 타겟 마커 위치 업데이트 (적의 위치 추적)
        self.marker.position = self.position

    def destroy_enemy(self):
        global score
        score += 100
        score_text.text = f'Score: {score}'

        # 파괴 이펙트 (간단한 색상 변화 및 스케일 축소 후 제거)
        explode = Entity(model='sphere', color=color.orange, position=self.position, scale=1)
        explode.animate_scale(5, duration=0.2, curve=curve.out_expo)
        explode.fade_out(duration=0.2)
        destroy(explode, delay=0.2)

        destroy(self.marker)
        destroy(self)

# 적 스폰 매니저
enemies = []
def spawn_enemy():
    x = random.uniform(-100, 100)
    y = random.uniform(-20, 50)
    z = player.z + random.uniform(150, 250)
    new_enemy = Enemy(position=(x, y, z))
    enemies.append(new_enemy)

    # 주기적으로 계속 스폰
    invoke(spawn_enemy, delay=2)

# 게임 시작
player = Player()

# 초기 적 생성
for _ in range(10):
    x = random.uniform(-100, 100)
    y = random.uniform(-20, 50)
    z = random.uniform(50, 200)
    enemies.append(Enemy(position=(x, y, z)))

spawn_enemy()

def input(key):
    if key == 'escape':
        quit()

# 실행 안내 메시지
print("-" * 50)
print("1950s Propeller Shooter 구동 중...")
print("조작 방법:")
print("- 마우스 이동: 비행기 회전 (Pitch/Yaw)")
print("- 마우스 왼쪽 클릭: 기관총 사격")
print("- W 키: 부스트 가속")
print("- ESC 키: 게임 종료")
print("-" * 50)

app.run()
