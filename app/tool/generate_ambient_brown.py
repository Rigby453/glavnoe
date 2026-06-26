import struct, math, random

# Детерминированный коричневый шум, бесшовный луп ~6 с, 22050 Hz, моно 16-bit PCM.
SR = 22050
SECONDS = 6
N = SR * SECONDS
FADE = SR // 2  # 0.5 с кросс-фейд на стыке для бесшовности

random.seed(20260625)

# Коричневый шум = интегрированный белый шум (случайное блуждание) с лёгким
# затуханием (leaky integrator), чтобы не уходило в клиппинг.
b = [0.0] * N
v = 0.0
for i in range(N):
    white = random.uniform(-1.0, 1.0)
    v = (v + 0.02 * white) * 0.995
    b[i] = v

# Нормализуем к пику ~0.9
peak = max(1e-9, max(abs(x) for x in b))
g = 0.9 / peak
b = [x * g for x in b]

# Бесшовный луп: кросс-фейдим последние FADE сэмплов с первыми FADE.
# Берём "ядро" длиной N-FADE, его хвост смешиваем с головой так, чтобы
# конец плавно переходил в начало при зацикливании.
core = N - FADE
out = b[:core]
for i in range(FADE):
    t = i / FADE
    # конец ядра (out[i] это начало) смешиваем с хвостом
    out[i] = b[i] * (t) + b[core + i] * (1 - t)

# 16-bit PCM
frames = b''.join(struct.pack('<h', int(max(-1.0, min(1.0, s)) * 32767)) for s in out)

n = len(out)
data_size = n * 2
path = "C:/Users/alune/glavnoe/app/assets/audio/ambient_brown.wav"
with open(path, 'wb') as f:
    f.write(b'RIFF')
    f.write(struct.pack('<I', 36 + data_size))
    f.write(b'WAVE')
    f.write(b'fmt ')
    f.write(struct.pack('<I', 16))
    f.write(struct.pack('<H', 1))   # PCM
    f.write(struct.pack('<H', 1))   # mono
    f.write(struct.pack('<I', SR))
    f.write(struct.pack('<I', SR * 2))
    f.write(struct.pack('<H', 2))
    f.write(struct.pack('<H', 16))
    f.write(b'data')
    f.write(struct.pack('<I', data_size))
    f.write(frames)
print("wrote", path, data_size + 44, "bytes,", n, "samples")
