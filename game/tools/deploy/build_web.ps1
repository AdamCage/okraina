# Сборка веб-версии игры и (по флагу) деплой на ВМ.
#   powershell -File tools\deploy\build_web.ps1            # только собрать
#   powershell -File tools\deploy\build_web.ps1 -Deploy     # собрать и выложить
#   powershell -File tools\deploy\build_web.ps1 -Selftest   # прогнать самотест в окне со скриншотами
param(
	[switch]$Deploy,
	[switch]$Selftest,
	[string]$Preset = "Web"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $root

## Бинарник Godot ищем в трёх местах: рядом с проектом, в <проект>\tools\godot
## и в <репозиторий>\tools\godot (в репозитории каталог tools/godot в .gitignore).
function Find-Godot([string]$Name) {
	foreach ($dir in @($root, (Join-Path $root "tools\godot"), (Join-Path $root "..\tools\godot"))) {
		$path = Join-Path $dir $Name
		if (Test-Path $path) { return (Resolve-Path $path).Path }
	}
	throw "Не найден $Name — положите бинарники Godot 4.7.2 в tools\godot\"
}
$godot = Find-Godot "Godot_v4.7.2-stable_win64_console.exe"
$godotWindow = Find-Godot "Godot_v4.7.2-stable_win64.exe"

## python нужен для tools\deploy\*.py — путь ищем явно, чтобы сборка падала
## с понятной ошибкой, а не молча пропускала пост-обработку и проверку пака.
$python = (Get-Command python -ErrorAction SilentlyContinue).Source
if (-not $python) { throw "Не найден python (нужен для tools\deploy\*.py)" }

## Запуск внешней программы с захватом stdout и stderr. Два «очевидных» способа
## не годятся:
##   * `& exe 2>&1` — PowerShell 5.1 при $ErrorActionPreference='Stop' обрывает
##     скрипт на первой же строке stderr (NativeCommandError);
##   * `cmd /c "exe > log 2>&1"` — консольная обёртка Godot уводит stderr движка
##     прямо в консоль мимо файла, и лог молча рвётся на середине.
## Поэтому потоки перенаправляются на уровне процесса, а наружу отдаётся
## объект {Code, Text} (Text = stdout + stderr).
function Invoke-Captured([string]$Exe, [string[]]$Argv) {
	$out = Join-Path $env:TEMP ("zona_build_" + [guid]::NewGuid().ToString("N") + ".out")
	$err = $out + ".err"
	$list = @($Argv | ForEach-Object { if ("$_" -match "\s") { '"' + $_ + '"' } else { "$_" } })
	$proc = Start-Process -FilePath $Exe -ArgumentList $list -WorkingDirectory $root `
		-NoNewWindow -Wait -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
	$text = [System.IO.File]::ReadAllText($out, [System.Text.Encoding]::UTF8) +
		[System.IO.File]::ReadAllText($err, [System.Text.Encoding]::UTF8)
	Remove-Item $out, $err -Force -ErrorAction SilentlyContinue
	return New-Object psobject -Property @{ Code = $proc.ExitCode; Text = $text }
}

Write-Host "[1/5] Импорт ресурсов (атласы, спрайты, звуки)..." -ForegroundColor Cyan
$import = Invoke-Captured $godot @("--headless", "--path", ".", "--import")
$import.Text -split "`n" | Select-String -Pattern "ERROR|SCRIPT ERROR" | Select-Object -First 20
if ($import.Code -ne 0) { Write-Host "  импорт завершился с кодом $($import.Code)" -ForegroundColor Yellow }

Write-Host "[2/5] Проверка сборки скриптов..." -ForegroundColor Cyan
# Полноценная проверка компиляции — сам тест игры (--check-only не видит автолоады).
$self = Invoke-Captured $godot @("--headless", "--path", ".", "--", "--selftest")
$selftestOut = $self.Text
if ($selftestOut -match "SCRIPT ERROR|Parse Error") {
	$selftestOut -split "`n" | Select-String "SCRIPT ERROR|Parse Error" | Select-Object -First 10
	throw "Есть ошибки скриптов — исправьте перед экспортом"
}
Write-Host "  ошибок скриптов нет" -ForegroundColor Green

Write-Host "[3/5] Самотест игры (headless)..." -ForegroundColor Cyan
$selftestOut -split "`n" | Select-String -Pattern "^\[|^===" | Select-Object -Last 25

if ($Selftest) {
	Write-Host "[3b] Самотест в окне + скриншоты..." -ForegroundColor Cyan
	$selfShot = Invoke-Captured $godotWindow @("--path", ".", "--", "--selftest", "--shot")
	$selfShot.Text -split "`n" | Select-String -Pattern "^\[|===" | Select-Object -Last 30
	if ($selfShot.Code -ne 0) { Write-Host "  самотест в окне: код $($selfShot.Code)" -ForegroundColor Yellow }
}

Write-Host "[4/5] Экспорт Web-сборки ($Preset)..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path (Join-Path $root "build\web") | Out-Null
$export = Invoke-Captured $godot @("--headless", "--path", ".", "--export-release", $Preset,
	"build/web/index.html")
$export.Text -split "`n" | Where-Object { $_.Trim() -ne "" } | Select-Object -Last 12
if ($export.Code -ne 0) { throw "Экспорт не удался (код $($export.Code))" }

Write-Host "[4b] Мобильная обвязка index.html..." -ForegroundColor Cyan
$env:PYTHONIOENCODING = "utf-8"
$pp = Invoke-Captured $python @((Join-Path $root "tools\deploy\postprocess_web.py"))
Write-Host $pp.Text.TrimEnd()
if ($pp.Code -ne 0) { throw "postprocess_web.py завершился с кодом $($pp.Code)" }

Write-Host "[4c] Проверка содержимого index.pck..." -ForegroundColor Cyan
$pck = Invoke-Captured $python @((Join-Path $root "tools\deploy\check_pck.py"))
Write-Host $pck.Text.TrimEnd()
if ($pck.Code -ne 0) { throw "check_pck.py: в паке нет нужных ресурсов (код $($pck.Code))" }

$size = (Get-ChildItem (Join-Path $root "build\web") -Recurse -File | Measure-Object -Property Length -Sum).Sum
Write-Host ("  сборка: {0:N2} МБ" -f ($size / 1MB)) -ForegroundColor Green

if ($Deploy) {
	Write-Host "[5/5] Деплой на ВМ (nginx + TLS)..." -ForegroundColor Cyan
	$env:PYTHONIOENCODING = "utf-8"
	$dep = Invoke-Captured $python @((Join-Path $root "tools\deploy\deploy.py"),
		"upload", "nginx", "cert", "verify")
	Write-Host $dep.Text.TrimEnd()
	if ($dep.Code -ne 0) { throw "deploy.py завершился с кодом $($dep.Code)" }
} else {
	Write-Host "[5/5] Деплой пропущен (запустите с -Deploy)" -ForegroundColor Yellow
}
