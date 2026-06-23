# cleanup-test-procs.ps1
# Гасит зависшие/осиротевшие процессы тест-прогонов, которые остаются после
# оборвавшихся по сети агентов и КОНКУРИРУЮТ со следующими прогонами
# (flutter test / build_runner / jest) — из-за чего верификация подвисает на минуты.
#
# Использование:
#   pwsh scripts/cleanup-test-procs.ps1            # killflutter_tester + dart (безопасно)
#   pwsh scripts/cleanup-test-procs.ps1 -IncludeNode  # ещё и node (ВНИМАНИЕ: убьёт и backend `npm run dev`)
#
# Почему так:
#  - flutter_tester — всегда процессы flutter-тестов, гасим всегда.
#  - dart — тест-изоляты И Dart Analysis Server; гасить безопасно (анализатор
#    перезапустится сам в IDE), для чистого прогона это нужно.
#  - node — это и jest-воркеры, и запущенный backend dev-сервер. По умолчанию
#    НЕ трогаем, чтобы не уронить твой `npm run dev`. Флаг -IncludeNode — когда
#    точно нужно (например, перед чистым `npm test`).

param(
  [switch]$IncludeNode
)

$targets = @('flutter_tester', 'dart')
if ($IncludeNode) { $targets += 'node' }

$killed = 0
foreach ($name in $targets) {
  $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
  if ($procs) {
    foreach ($p in $procs) {
      try { Stop-Process -Id $p.Id -Force -ErrorAction Stop; $killed++ }
      catch { Write-Warning "Не смог убить $name (PID $($p.Id)): $($_.Exception.Message)" }
    }
  }
}

Start-Sleep -Milliseconds 400
$still = Get-Process -Name $targets -ErrorAction SilentlyContinue
if ($still) {
  Write-Output "Убито: $killed. ВСЁ ЕЩЁ живы: $($still.Count) ($(( $still | Select-Object -ExpandProperty Name -Unique ) -join ', '))"
} else {
  Write-Output "Убито: $killed. Чисто — процессов тест-прогонов не осталось."
}
if (-not $IncludeNode) {
  Write-Output "(node не трогали — добавь -IncludeNode перед чистым 'npm test', если backend dev-сервер не запущен.)"
}
