# Запуск Kaizen на телефоне: находит LAN IP ноутбука и запускает flutter run
# с --dart-define=API_BASE_URL=http://<LAN_IP>:3000, чтобы телефон видел бэкенд.
#
# Использование (из корня репо или откуда угодно):
#   powershell -ExecutionPolicy Bypass -File scripts\run-phone.ps1
#   # дополнительные аргументы уходят в flutter run, например выбор устройства:
#   powershell -ExecutionPolicy Bypass -File scripts\run-phone.ps1 -- -d <device-id>
#
# Требования: телефон подключён по USB (flutter devices его видит),
# бэкенд запущен (cd backend; npm run dev), телефон и ноутбук в одной Wi-Fi сети.

param(
    [int]$Port = 3000,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArgs
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$appDir = Join-Path $repoRoot 'app'

# --- 1. LAN IP: берём интерфейс с маршрутом по умолчанию (реальная сеть, не виртуалки) ---
$defaultRoute = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
    Sort-Object RouteMetric, ifMetric | Select-Object -First 1
if ($null -eq $defaultRoute) {
    Write-Error 'Не найден маршрут по умолчанию — ноутбук не подключён к сети?'
}
$lanIp = (Get-NetIPAddress -InterfaceIndex $defaultRoute.InterfaceIndex -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike '169.254.*' -and $_.IPAddress -ne '127.0.0.1' } |
    Select-Object -First 1).IPAddress
if ([string]::IsNullOrEmpty($lanIp)) {
    Write-Error 'Не удалось определить LAN IPv4-адрес.'
}

$apiUrl = "http://${lanIp}:${Port}"
Write-Host "LAN IP ноутбука: $lanIp" -ForegroundColor Green
Write-Host "API_BASE_URL:    $apiUrl" -ForegroundColor Green

# --- 2. Проверка, что бэкенд отвечает (не блокирует запуск, только предупреждает) ---
try {
    $health = Invoke-RestMethod -Uri "http://localhost:${Port}/health" -TimeoutSec 3
    Write-Host "Бэкенд работает (health: $($health.status))" -ForegroundColor Green
} catch {
    Write-Host "ВНИМАНИЕ: бэкенд на порту $Port не отвечает. Запусти его: cd backend; npm run dev" -ForegroundColor Yellow
    Write-Host '(flutter всё равно запустится — приложение работает offline-first)' -ForegroundColor Yellow
}

# --- 3. flutter run с нужным dart-define ---
Push-Location $appDir
try {
    flutter run --dart-define=API_BASE_URL=$apiUrl @FlutterArgs
} finally {
    Pop-Location
}
