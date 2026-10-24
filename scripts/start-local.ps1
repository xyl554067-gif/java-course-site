$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runDir = Join-Path $repo '.local-run'
$logDir = Join-Path $runDir 'logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$backendLog = Join-Path $logDir 'backend.log'
$backendErrorLog = Join-Path $logDir 'backend-error.log'
$frontendLog = Join-Path $logDir 'frontend.log'
$frontendErrorLog = Join-Path $logDir 'frontend-error.log'
$databaseLog = Join-Path $logDir 'database-start.log'

function Test-Port([int]$Port) {
  $client = [System.Net.Sockets.TcpClient]::new()
  try { $task = $client.ConnectAsync('127.0.0.1', $Port); return $task.Wait(500) -and $client.Connected }
  catch { return $false }
  finally { $client.Dispose() }
}

function Wait-Port([int]$Port, [int]$Seconds) {
  for ($i=0; $i -lt $Seconds; $i++) { if (Test-Port $Port) { return $true }; Start-Sleep -Seconds 1 }
  return $false
}

try {
  if (-not (Test-Port 54321)) {
    $adminLauncher = Join-Path $PSScriptRoot 'start-kingbase-elevated.ps1'
    try {
      Start-Process -FilePath 'powershell.exe' -Verb RunAs -WindowStyle Hidden -Wait -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$adminLauncher`"")
    } catch { throw "KingBase 需要管理员权限启动，未能启动。请在管理员权限下重试；日志：$databaseLog" }
    if (-not (Wait-Port 54321 25)) { throw "KingBase 未在 25 秒内监听 54321。请检查数据目录或管理员启动提示；日志：$databaseLog" }
  }

  if (-not (Test-Port 8080)) {
    $jar = Join-Path $repo 'backend/target/javacourse-server-1.0.0.jar'
    $bootable = $false
    if (Test-Path $jar) { $bootable = [bool](& jar.exe tf $jar 2>$null | Select-String -Quiet 'BOOT-INF/') }
    if (-not $bootable) {
      $maven = Join-Path $repo 'tools/apache-maven-3.9.9/bin/mvn.cmd'
      if (-not (Test-Path $maven)) { $mavenCommand = Get-Command mvn.cmd -ErrorAction SilentlyContinue; if ($mavenCommand) { $maven = $mavenCommand.Source } }
      if (-not $maven) { throw "后端程序包无效且找不到 Maven。查看启动日志：$backendLog" }
      Push-Location (Join-Path $repo 'backend')
      try { & $maven -B -DskipTests -Pkingbase-local package *>> $backendLog; if ($LASTEXITCODE -ne 0) { throw "后端打包失败，详见 $backendLog" } }
      finally { Pop-Location }
      if (-not (Test-Path $jar)) { throw "后端打包后仍未生成程序包，详见 $backendLog" }
    }
    Start-Process -FilePath 'java.exe' -ArgumentList @('-jar',"`"$jar`"",'--server.port=8080') -WorkingDirectory (Join-Path $repo 'backend') -WindowStyle Hidden -RedirectStandardOutput $backendLog -RedirectStandardError $backendErrorLog | Out-Null
    if (-not (Wait-Port 8080 35)) { throw "后端 8080 未启动。查看日志：$backendLog" }
  }
  $apiReady = $false
  for ($i=0; $i -lt 30; $i++) {
    try { $health = Invoke-RestMethod 'http://127.0.0.1:8080/api/health' -TimeoutSec 2; if ($health.status -eq 'UP' -and $health.database -eq 'UP') { $apiReady = $true; break } }
    catch { Start-Sleep -Seconds 1 }
  }
  if (-not $apiReady) { throw "后端端口已打开，但数据库/API健康检查未通过。查看日志：$backendLog" }

  $front = Join-Path $repo 'frontend'
  if (-not (Test-Port 5173)) {
    if (-not (Test-Path (Join-Path $front 'node_modules'))) { Push-Location $front; try { npm.cmd install } finally { Pop-Location } }
    Start-Process -FilePath 'npm.cmd' -ArgumentList @('run','dev','--','--host','127.0.0.1') -WorkingDirectory $front -WindowStyle Hidden -RedirectStandardOutput $frontendLog -RedirectStandardError $frontendErrorLog | Out-Null
    if (-not (Wait-Port 5173 25)) { throw "前端 5173 未启动。查看日志：$frontendLog" }
  }
  Start-Process 'http://127.0.0.1:5173/#/'
} catch {
  $message = "本地课程站启动失败：`n$($_.Exception.Message)`n`n日志目录：$logDir"
  Add-Type -AssemblyName PresentationFramework
  [System.Windows.MessageBox]::Show($message, 'Java 课程站启动器', 'OK', 'Error') | Out-Null
  exit 1
}
