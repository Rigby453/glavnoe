# cleanup-test-procs.ps1
# Гасит зависшие/осиротевшие процессы ТЕСТ-прогонов, которые остаются после
# оборвавшихся по сети агентов и КОНКУРИРУЮТ со следующими прогонами
# (flutter test / build_runner / jest) — из-за чего верификация подвисает на минуты.
#
# Использование:
#   pwsh scripts/cleanup-test-procs.ps1            # flutter_tester + тест/билд-изоляты dart
#   pwsh scripts/cleanup-test-procs.ps1 -IncludeNode  # ещё и node (ВНИМАНИЕ: убьёт и backend `npm run dev`)
#
# ВАЖНО (почему так аккуратно с dart):
#  - flutter_tester — всегда процессы flutter-тестов → гасим всегда.
#  - dart — это И тест/билд-изоляты, И **Dart Analysis Server** твоей IDE (подсветка,
#    автодополнение). РАНЬШЕ скрипт гасил ВСЕ dart и сносил анализатор → в IDE
#    выскакивала плашка «Restart Dart». Теперь по командной строке отличаем тест/билд
#    от анализатора и НЕ трогаем Analysis Server / language-server.
#  - node — это и jest-воркеры, и запущенный backend dev-сервер. По умолчанию
#    НЕ трогаем, чтобы не уронить твой `npm run dev`. Флаг -IncludeNode — когда
#    точно нужно (например, перед чистым `npm test`).

param(
  [switch]$IncludeNode
)

$killed = 0

# 1) flutter_tester — всегда тестовые, гасим все.
foreach ($p in Get-Process -Name 'flutter_tester' -ErrorAction SilentlyContinue) {
  try { Stop-Process -Id $p.Id -Force -ErrorAction Stop; $killed++ }
  catch { Write-Warning "Не смог убить flutter_tester (PID $($p.Id)): $($_.Exception.Message)" }
}

# 2) dart — гасим ТОЛЬКО тест/билд-изоляты, НЕ анализатор IDE.
#    KILL только если командная строка похожа на тест/билд-прогон,
#    и НИКОГДА — если это Analysis Server / language-server / DevTools / DDS.
$killPattern = 'flutter_tools|build_runner|flutter_test|\btest\b|test_runner|\.dart_tool'
$skipPattern = 'analysis_server|language-server|language_server|analyzer|devtools|\bdds\b|lsp'

$dartProcs = Get-CimInstance Win32_Process -Filter "Name = 'dart.exe'" -ErrorAction SilentlyContinue
foreach ($proc in $dartProcs) {
  $cl = $proc.CommandLine
  if ([string]::IsNullOrEmpty($cl)) { continue }            # без командной строки — не трогаем (на всякий случай)
  if ($cl -match $skipPattern) { continue }                 # анализатор/LSP/DevTools — НЕ трогаем
  if ($cl -notmatch $killPattern) { continue }              # не похоже на тест/билд — НЕ трогаем
  try { Stop-Process -Id $proc.ProcessId -Force -ErrorAction Stop; $killed++ }
  catch { Write-Warning "Не смог убить dart (PID $($proc.ProcessId)): $($_.Exception.Message)" }
}

# 3) node — только по флагу.
if ($IncludeNode) {
  foreach ($p in Get-Process -Name 'node' -ErrorAction SilentlyContinue) {
    try { Stop-Process -Id $p.Id -Force -ErrorAction Stop; $killed++ }
    catch { Write-Warning "Не смог убить node (PID $($p.Id)): $($_.Exception.Message)" }
  }
}

Start-Sleep -Milliseconds 400
Write-Output "Убито тест-процессов: $killed (Dart Analysis Server IDE не трогали)."
if (-not $IncludeNode) {
  Write-Output "(node не трогали — добавь -IncludeNode перед чистым 'npm test', если backend dev-сервер не запущен.)"
}
