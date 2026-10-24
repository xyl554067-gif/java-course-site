$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$logDir=Join-Path $repo '.local-run/logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$ctl='D:\Kingbase\KESRealPro\V008R006C009B0014\Server\bin\sys_ctl.exe'
$data='D:\KingBase\data'
$log=Join-Path $logDir 'database-start.log'
if(-not(Test-Path $ctl)){"KingBase sys_ctl.exe not found: $ctl"|Set-Content $log;exit 2}
if(-not(Test-Path $data)){"KingBase data directory not found: $data"|Set-Content $log;exit 3}
& $ctl -D $data start *>&1 | Tee-Object -FilePath $log
exit $LASTEXITCODE
