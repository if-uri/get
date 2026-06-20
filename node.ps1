<#
  Install and run an urirun node on Windows (PowerShell).

  Usage:
    irm https://get.ifuri.com/node.ps1 | iex
    powershell -ExecutionPolicy Bypass -File node.ps1 -Name laptop -Port 8765 -Service

  Mirrors node.sh: venv in %USERPROFILE%\.urirun-node, urirun pinned via -Ref,
  a validated v2 registry, and `urirun node serve`. -Service registers a logon
  Scheduled Task so the node survives reboot (Windows has no systemd).
#>
[CmdletBinding()]
param(
  [string]$Name = $env:COMPUTERNAME,
  [int]$Port = 8765,
  [string]$Bind = "0.0.0.0",
  [string]$Dir = (Join-Path $HOME ".urirun-node"),
  [string]$Python = "python",
  [string]$Ref = $(if ($env:URIRUN_REF) { $env:URIRUN_REF } else { "v0.3.14" }),
  [switch]$Service,
  [switch]$DryRun,
  [switch]$NoStart,
  [switch]$Help
)

$ErrorActionPreference = "Stop"

function Die($msg) { Write-Error $msg; exit 1 }
function Info($msg) { Write-Host "==> $msg" }

if ($Help) {
  Write-Host @"
Install and run an urirun node (Windows).

  -Name NAME     Node name used as URI target. Default: computer name.
  -Port PORT     HTTP port. Default: 8765.
  -Bind ADDR     Bind address. Default: 0.0.0.0.
  -Dir PATH      Install directory. Default: %USERPROFILE%\.urirun-node.
  -Python PATH   Python launcher. Default: python.
  -Ref REF       urirun git tag/branch. Default: v0.3.14 (env: URIRUN_REF).
  -Service       Register a logon Scheduled Task (survives reboot).
  -DryRun        Configure node without executing command routes.
  -NoStart       Install and configure, but do not start.
  -Help          Show this help.
"@
  exit 0
}

$GitUrl = "git+https://github.com/if-uri/urirun.git@$Ref#subdirectory=adapters/python"
$NodeName = ($Name -replace '[^A-Za-z0-9_.-]', '-').ToLower().Trim('-')
if (-not $NodeName) { $NodeName = "node" }

$VenvDir  = Join-Path $Dir ".venv"
$VenvPy   = Join-Path $VenvDir "Scripts\python.exe"
$VenvUri  = Join-Path $VenvDir "Scripts\urirun.exe"
$Bindings = Join-Path $Dir "bindings.v2.json"
$Registry = Join-Path $Dir "registry.json"
$NodeCfg  = Join-Path $Dir "node.json"
$Runner   = Join-Path $Dir "run-node.cmd"
$LogFile  = Join-Path $Dir "node.log"

if (-not (Get-Command $Python -ErrorAction SilentlyContinue)) {
  Die "Python not found ('$Python'); install Python 3 and retry."
}

Info "Installing urirun node `"$NodeName`" in $Dir (urirun $Ref)"
New-Item -ItemType Directory -Force -Path $Dir | Out-Null
& $Python -m venv $VenvDir
& $VenvPy -m pip install --upgrade pip | Out-Null
& $VenvPy -m pip install --upgrade $GitUrl

# urirun command snippets are OS-agnostic (python -c). Embed the venv python with
# JSON-escaped backslashes.
$PyJson = $VenvPy -replace '\\', '\\'

$BindingsJson = @'
{
  "version": "urirun.bindings.v2",
  "bindings": {
    "env://__NODE__/runtime/query/health": {
      "kind": "command", "adapter": "argv-template",
      "inputSchema": { "type": "object", "additionalProperties": false, "properties": {} },
      "argv": ["__PY__", "-c", "import json,platform,socket; print(json.dumps({'hostname':socket.gethostname(),'platform':platform.platform(),'python':platform.python_version()}))"],
      "policy": { "allowExecute": true, "maxArgs": 8 },
      "meta": { "title": "Node runtime health" }
    },
    "shell://__NODE__/command/date": {
      "kind": "command", "adapter": "argv-template",
      "inputSchema": { "type": "object", "additionalProperties": false, "properties": {} },
      "argv": ["__PY__", "-c", "import datetime; print(datetime.datetime.now().astimezone().isoformat())"],
      "policy": { "allowExecute": true, "maxArgs": 8 },
      "meta": { "title": "Print local date" }
    },
    "shell://__NODE__/command/which": {
      "kind": "command", "adapter": "argv-template",
      "inputSchema": { "type": "object", "additionalProperties": false, "required": ["binary"], "properties": { "binary": { "type": "string", "minLength": 1 } } },
      "argv": ["__PY__", "-c", "import shutil,sys; print(shutil.which(sys.argv[1]) or '')", "{binary}"],
      "policy": { "allowExecute": true, "maxArgs": 8 },
      "meta": { "title": "Find executable path" }
    }
  }
}
'@
$BindingsJson = $BindingsJson.Replace('__PY__', $PyJson).Replace('__NODE__', $NodeName)
Set-Content -Path $Bindings -Value $BindingsJson -Encoding UTF8

& $VenvUri validate $Bindings | Out-Null
& $VenvUri compile $Bindings --out $Registry | Out-Null

$InitArgs = @("node", "init", "--config", $NodeCfg, "--name", $NodeName, "--registry", $Registry, "--host", $Bind, "--port", "$Port")
if (-not $DryRun) { $InitArgs += "--execute" }
& $VenvUri @InitArgs | Out-Null

$ServeFlag = if ($DryRun) { "" } else { " --execute" }
Set-Content -Path $Runner -Value "@echo off`r`n`"$VenvUri`" node serve --config `"$NodeCfg`"$ServeFlag" -Encoding ASCII

$NodeIp = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $_.IPAddress -notlike '169.*' -and $_.IPAddress -ne '127.0.0.1' } |
  Select-Object -First 1 -ExpandProperty IPAddress)
if (-not $NodeIp) { $NodeIp = "NODE_IP" }

Info "Node configured"
Write-Host "bindings: $Bindings"
Write-Host "registry: $Registry"
Write-Host "config:   $NodeCfg"
Write-Host "runner:   $Runner"
Write-Host ""
Info "On the host computer, register this node:"
Write-Host "urirun host add-node $NodeName http://$NodeIp`:$Port"
Write-Host ""

function Wait-Health {
  Info "Waiting for node health on 127.0.0.1:$Port ..."
  for ($i = 0; $i -lt 20; $i++) {
    try {
      Invoke-WebRequest -UseBasicParsing -TimeoutSec 1 "http://127.0.0.1:$Port/health" | Out-Null
      Info "Node healthy. LAN: http://$NodeIp`:$Port/  (health: /health)"
      return
    } catch { Start-Sleep -Milliseconds 500 }
  }
  Info "Warning: node not healthy yet; check $LogFile"
}

if ($NoStart) { Info "Not starting node because -NoStart was used."; exit 0 }

if ($Service) {
  $action  = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$Runner`" > `"$LogFile`" 2>&1"
  $trigger = New-ScheduledTaskTrigger -AtLogOn
  $set     = New-ScheduledTaskSettingsSet -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
  Register-ScheduledTask -TaskName "urirun-node" -Action $action -Trigger $trigger -Settings $set -Force | Out-Null
  Start-ScheduledTask -TaskName "urirun-node"
  Info "Scheduled Task 'urirun-node' registered (runs at logon, survives reboot)."
  Write-Host "    stop: Unregister-ScheduledTask -TaskName urirun-node -Confirm:`$false"
  Wait-Health
  exit 0
}

Info "Starting urirun node in background (log: $LogFile)"
Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$Runner`" > `"$LogFile`" 2>&1" -WindowStyle Hidden
Wait-Health
