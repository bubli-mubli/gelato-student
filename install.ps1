# Gelato Student — учебный режим для OpenCode, Claude Code и Codex (Windows / PowerShell).
#
#   irm https://raw.githubusercontent.com/bubli-mubli/gelato-student/main/install.ps1 | iex
#   .\install.ps1 -Default        ещё и включить режим по умолчанию
#   .\install.ps1 -Only claude    только Claude Code (или -Only opencode, -Only codex)
#   .\install.ps1 -Uninstall      удалить всё, что поставил установщик, и вернуть бэкапы
#
# Если PowerShell запрещает скрипты: powershell -ExecutionPolicy Bypass -File .\install.ps1

param(
  [string]$Only = "",
  [switch]$Default,
  [switch]$Uninstall
)
$ErrorActionPreference = "Stop"

$Slug = if ($env:GELATO_REPO) { $env:GELATO_REPO } else { "bubli-mubli/gelato-student" }
$Branch = if ($env:GELATO_BRANCH) { $env:GELATO_BRANCH } else { "main" }
$Skills = "gelato-hints", "gelato-review", "gelato-debug", "gelato-explain", "gelato-teach-back", "gelato-practice", "gelato-progress"
$HomeDir = Join-Path $env:USERPROFILE ".gelato-student"
$Manifest = Join-Path $HomeDir "manifest.tsv"
$OcDir = if ($env:OPENCODE_CONFIG_HOME) { $env:OPENCODE_CONFIG_HOME } else { Join-Path $env:USERPROFILE ".config\opencode" }
$CcDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE ".claude" }
$CxDir = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }
$AgDir = Join-Path $env:USERPROFILE ".agents\skills"

function Ok($m) { Write-Host "✓ $m" -ForegroundColor Green }
function Info($m) { Write-Host "  $m" }

# ── удаление ──
if ($Uninstall) {
  if (-not (Test-Path $Manifest)) { throw "Gelato Student не установлен (нет $Manifest)" }
  foreach ($line in Get-Content $Manifest) {
    if (-not $line) { continue }
    $dest, $backup = $line -split "`t"
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    if ($backup -and (Test-Path $backup)) { Move-Item $backup $dest; Info "вернул $dest из бэкапа" }
  }
  foreach ($f in (Join-Path $OcDir "opencode.json"), (Join-Path $CcDir "settings.json"), (Join-Path $CxDir "AGENTS.md")) {
    if (Test-Path "$f.gelato.bak") { Move-Item "$f.gelato.bak" $f -Force; Info "вернул $f" }
    if (Test-Path "$f.gelato.new") { Remove-Item $f, "$f.gelato.new" -Force; Info "удалил $f" }
  }
  Remove-Item $HomeDir -Recurse -Force
  Ok "Gelato Student удалён"
  return
}

# ── исходники: папка рядом со скриптом или архив с GitHub ──
$Src = $null
if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "skills\gelato-hints"))) { $Src = $PSScriptRoot }
if (-not $Src) {
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ("gelato-" + [guid]::NewGuid())
  New-Item -ItemType Directory $tmp | Out-Null
  Write-Host "Скачиваю набор с github.com/$Slug…"
  $zip = Join-Path $tmp "kit.zip"
  Invoke-WebRequest "https://codeload.github.com/$Slug/zip/refs/heads/$Branch" -OutFile $zip -UseBasicParsing
  Expand-Archive $zip -DestinationPath $tmp
  $Src = (Get-ChildItem $tmp -Directory | Select-Object -First 1).FullName
}

$wantOc = $true; $wantCc = $true; $wantCx = $true
switch ($Only) {
  "" {
    $hasOc = (Get-Command opencode -ErrorAction SilentlyContinue) -or (Test-Path $OcDir)
    $hasCc = (Get-Command claude -ErrorAction SilentlyContinue) -or (Test-Path $CcDir)
    $hasCx = (Get-Command codex -ErrorAction SilentlyContinue) -or (Test-Path $CxDir)
    if ($hasOc -or $hasCc -or $hasCx) { $wantOc = [bool]$hasOc; $wantCc = [bool]$hasCc; $wantCx = [bool]$hasCx }
    else { Write-Warning "Не нашёл ни OpenCode, ни Claude Code, ни Codex — ставлю для всех." }
  }
  "opencode" { $wantCc = $false; $wantCx = $false }
  "claude" { $wantOc = $false; $wantCx = $false }
  "codex" { $wantOc = $false; $wantCc = $false }
  default { throw "-Only: opencode, claude или codex" }
}

New-Item -ItemType Directory $HomeDir -Force | Out-Null
if (-not (Test-Path $Manifest)) { New-Item -ItemType File $Manifest | Out-Null }

function Put($src, $dest) {
  $known = Select-String -Path $Manifest -Pattern ([regex]::Escape($dest) + "`t") -Quiet
  $backup = ""
  New-Item -ItemType Directory (Split-Path $dest) -Force | Out-Null
  if ((Test-Path $dest) -and -not $known) {
    $backup = "$dest.gelato.bak"
    if (Test-Path $backup) { Remove-Item $backup -Recurse -Force }
    Move-Item $dest $backup
  }
  if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
  Copy-Item $src $dest -Recurse
  if (-not $known) { Add-Content $Manifest "$dest`t$backup" }
}

function SetJson($file, $key, $value) {
  New-Item -ItemType Directory (Split-Path $file) -Force | Out-Null
  if (Test-Path $file) {
    if (-not (Test-Path "$file.gelato.bak") -and -not (Test-Path "$file.gelato.new")) { Copy-Item $file "$file.gelato.bak" }
    $raw = Get-Content $file -Raw
    $obj = if ($raw.Trim()) { $raw | ConvertFrom-Json } else { [pscustomobject]@{} }
  } else {
    New-Item -ItemType File "$file.gelato.new" | Out-Null
    $obj = [pscustomobject]@{}
  }
  $obj | Add-Member -NotePropertyName $key -NotePropertyValue $value -Force
  $obj | ConvertTo-Json -Depth 20 | Set-Content $file -Encoding UTF8
}

if ($wantOc) {
  $ver = 2
  $oc = Get-Command opencode -ErrorAction SilentlyContinue
  if ($oc) {
    $raw = (& opencode --version 2>$null | Select-Object -First 1)
    if ($raw -match '(\d+)\.') { if ([int]$Matches[1] -lt 2) { $ver = 1 } }
  }
  $agent = if ($ver -eq 1) { "agents\opencode-v1\gelato-student.md" } else { "agents\opencode\gelato-student.md" }
  Put (Join-Path $Src $agent) (Join-Path $OcDir "agents\gelato-student.md")
  foreach ($s in $Skills) { Put (Join-Path $Src "skills\$s") (Join-Path $OcDir "skills\$s") }
  if ($Default) { SetJson (Join-Path $OcDir "opencode.json") "default_agent" "gelato-student" }
  Ok "OpenCode (формат V$ver): агент gelato-student и $($Skills.Count) скиллов → $OcDir"
}

if ($wantCc) {
  Put (Join-Path $Src "claude\gelato-student.md") (Join-Path $CcDir "output-styles\gelato-student.md")
  foreach ($s in $Skills) { Put (Join-Path $Src "skills\$s") (Join-Path $CcDir "skills\$s") }
  if ($Default) { SetJson (Join-Path $CcDir "settings.json") "outputStyle" "Gelato Student" }
  Ok "Claude Code: режим «Gelato Student» и $($Skills.Count) скиллов → $CcDir"
}

if ($wantCx) {
  Put (Join-Path $Src "codex\gelato-student") (Join-Path $AgDir "gelato-student")
  foreach ($s in $Skills) { Put (Join-Path $Src "skills\$s") (Join-Path $AgDir $s) }
  if ($Default) {
    $f = Join-Path $CxDir "AGENTS.md"
    New-Item -ItemType Directory $CxDir -Force | Out-Null
    if (Test-Path $f) {
      if (-not (Test-Path "$f.gelato.bak") -and -not (Test-Path "$f.gelato.new")) { Copy-Item $f "$f.gelato.bak" }
    } else { New-Item -ItemType File "$f.gelato.new" | Out-Null }
    if (-not ((Test-Path $f) -and (Select-String -Path $f -Pattern "gelato-student:begin" -Quiet))) {
      Add-Content $f "`n<!-- gelato-student:begin -->`nВсегда работай в учебном режиме: загрузи скилл gelato-student из ~/.agents/skills и следуй ему.`n<!-- gelato-student:end -->"
    }
  }
  Ok "Codex: режим `$gelato-student и $($Skills.Count) скиллов → $AgDir"
}

Write-Host ""
Write-Host "Дальше:"
if ($wantOc) { Info "OpenCode — запусти opencode в папке проекта и нажми Shift+Tab (в старых версиях Tab), пока не появится gelato-student." }
if ($wantCc) { Info "Claude Code — запусти claude в папке проекта, затем /config → Output style → Gelato Student." }
if ($wantCx) { Info "Codex — запусти codex в папке проекта и напиши `$gelato-student (перезапусти Codex, если он был открыт)." }
Info "Напиши «застрял» — и получишь первую подсказку, а не готовый код."
