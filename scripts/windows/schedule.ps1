<#
schedule.ps1 - the Windows scheduler for the transcript pipeline. The Mac uses launchd/.

WHAT IT DOES
  Registers, shows, runs and removes the two nightly jobs in Windows Task Scheduler, and
  sends a test notification. One file, five actions, so the install runbook adds one line per
  step instead of paragraphs, and an owner's vault keeps its own off switch after the cloned
  kit is deleted.

  install      register <LabelPrefix>-uploader and <LabelPrefix>-absorber, then print status
  status       one block per job: next run, last run, last result, and what it runs.
               An error here means the job is not registered.
  run          start one job now (-Job uploader|absorber), the same way the schedule will
  uninstall    remove both jobs, then print what is left (nothing, on success)
  notify-test  show one notification, the same kind a failed night shows

HOW IT MAPS TO THE MAC PLISTS
  StartCalendarInterval 22:10 / 08:30 + 22:40  ->  daily triggers at the same times
  launchd's explicit PATH                     ->  bash -l, which puts Git's own tools first,
                                                  so a bare sort or find is never Windows' own
  StandardOutPath / StandardErrorPath         ->  the >> redirections inside bash -c
  a run missed while asleep                   ->  StartWhenAvailable runs it on wake
  a laptop on battery                         ->  AllowStartIfOnBatteries, or the night is
                                                  silently skipped, which is the Windows default
  no window at 22:10                          ->  conhost --headless. A visible console that
                                                  the owner closes would kill the run.

WHY Register-ScheduledTask AND NOT schtasks
  schtasks /TR is capped at 261 characters, too short for a quoted bash path plus two log
  redirections, and from Git Bash its /TN argument is rewritten into a path by MSYS.

THE PRINCIPAL
  The owner, Interactive, not elevated. That is what lets `claude -p` see the owner's own
  credentials and connectors, and what lets a toast reach the screen. Never SYSTEM: git also
  refuses a repo owned by someone else. -LogonType S4U exists only for CI runners, which have
  no interactive session; it gives up the toast.

This file is ASCII on purpose: Windows PowerShell 5.1 reads a script without a byte order
mark in the local code page.

Called from Git Bash:
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w <kit>/scripts/windows/schedule.ps1)" \
      -Action install -LabelPrefix com.example.transcript -ScriptsDir "$(cygpath -m <folder holding the two .sh>)"
#>
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('install', 'status', 'run', 'uninstall', 'notify-test')]
  [string]$Action,
  [string]$LabelPrefix,
  [string]$ScriptsDir,
  [string]$LogDir = (Join-Path $env:LOCALAPPDATA 'transcript-pipeline\logs'),
  [string]$UploaderTime = '22:10',
  [string[]]$AbsorberTimes = @('08:30', '22:40'),
  [ValidateSet('uploader', 'absorber')]
  [string]$Job,
  [ValidateSet('Interactive', 'S4U')]
  [string]$LogonType = 'Interactive'
)
$ErrorActionPreference = 'Stop'

# From Git Bash an array arrives as one string, "08:30,22:40".
$AbsorberTimes = @($AbsorberTimes | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

function Find-GitBash {
  # Claude Code's own override first, then the Git for Windows registry, then the usual
  # folders, then derive it from git.exe. Never C:\Windows\System32\bash.exe: that is WSL.
  $c = @()
  if ($env:CLAUDE_CODE_GIT_BASH_PATH) { $c += $env:CLAUDE_CODE_GIT_BASH_PATH }
  foreach ($k in 'HKLM:\SOFTWARE\GitForWindows', 'HKCU:\SOFTWARE\GitForWindows') {
    $p = (Get-ItemProperty $k -ErrorAction SilentlyContinue).InstallPath
    if ($p) { $c += (Join-Path $p 'bin\bash.exe') }
  }
  $c += (Join-Path $env:ProgramFiles 'Git\bin\bash.exe')
  if ($env:LOCALAPPDATA) { $c += (Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\bash.exe') }
  $g = Get-Command git.exe -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($g) { $c += (Join-Path (Split-Path (Split-Path $g.Source)) 'bin\bash.exe') }
  foreach ($x in $c) {
    if ($x -and ($x -notmatch '\\System32\\') -and (Test-Path -LiteralPath $x)) { return (Resolve-Path -LiteralPath $x).Path }
  }
  throw 'Git for Windows was not found (no bin\bash.exe). Install it first: winget install -e --id Git.Git'
}

function Show-Toast([string]$Title, [string]$Message) {
  # The same script the two .sh files carry as a base64 constant (TOAST_B64). Windows
  # PowerShell 5.1 only: PowerShell 7 dropped the WinRT projection this needs. The app id is
  # PowerShell's own, so in Settings the toasts are listed under "Windows PowerShell".
  $m = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
  $t = $m::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
  $n = $t.GetElementsByTagName('text')
  $null = $n.Item(0).AppendChild($t.CreateTextNode($Title))
  $null = $n.Item(1).AppendChild($t.CreateTextNode($Message))
  $m::CreateToastNotifier('{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe').Show([Windows.UI.Notifications.ToastNotification]::new($t))
}

function Get-TaskNames { @("$LabelPrefix-uploader", "$LabelPrefix-absorber") }

function Register-Job([string]$Name, [string[]]$Times, [string]$Bash, [string]$Dir, [string]$Logs) {
  $log = "$Logs/transcript-$Name"
  $inner = "exec bash '$Dir/transcript-$Name.sh' >>'$log.stdout.log' 2>>'$log.stderr.log'"
  $action = New-ScheduledTaskAction -Execute (Join-Path $env:WINDIR 'System32\conhost.exe') `
    -Argument "--headless `"$Bash`" -l -c `"$inner`""
  $triggers = foreach ($t in $Times) {
    New-ScheduledTaskTrigger -Daily -At ([datetime]::ParseExact($t, 'HH:mm', [Globalization.CultureInfo]::InvariantCulture))
  }
  $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Hours 6) -MultipleInstances IgnoreNew
  $who = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType $LogonType -RunLevel Limited
  Register-ScheduledTask -TaskName "$LabelPrefix-$Name" -Action $action -Trigger $triggers -Settings $settings `
    -Principal $who -Force | Out-Null
}

function Show-Status {
  $missing = 0
  foreach ($name in Get-TaskNames) {
    $t = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
    if (-not $t) { "NOT REGISTERED: $name"; $missing++; continue }
    $i = $t | Get-ScheduledTaskInfo
    '{0}  state={1}  next={2}  last={3}  result=0x{4:X}' -f $t.TaskName, $t.State, $i.NextRunTime, $i.LastRunTime, $i.LastTaskResult
    '  runs: ' + $t.Actions[0].Execute + ' ' + $t.Actions[0].Arguments
  }
  if ($missing) { throw "$missing job(s) are not registered." }
}

try {
  if ($Action -ne 'notify-test' -and -not $LabelPrefix) { throw '-LabelPrefix is required (LABEL_PREFIX in config.sh).' }
  switch ($Action) {
    'install' {
      if (-not $ScriptsDir) { throw '-ScriptsDir is required: the folder that holds transcript-uploader.sh.' }
      $dir = ($ScriptsDir -replace '\\', '/').TrimEnd('/')
      $logs = ($LogDir -replace '\\', '/').TrimEnd('/')
      # Single quotes wrap both paths inside bash -c, so a quote in either would break the
      # command the task runs, silently, at 22:10. Refuse here instead. Spaces and Hebrew are fine.
      if ($dir.Contains("'") -or $logs.Contains("'")) {
        throw "A path contains a single quote, which the scheduled command cannot carry: $dir or $logs. Move the folder to a path without one."
      }
      foreach ($n in 'uploader', 'absorber') {
        if (-not (Test-Path -LiteralPath "$dir/transcript-$n.sh")) { throw "Not found: $dir/transcript-$n.sh" }
      }
      $bash = Find-GitBash
      New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
      Register-Job 'uploader' @($UploaderTime) $bash $dir $logs
      Register-Job 'absorber' $AbsorberTimes $bash $dir $logs
      Show-Status
    }
    'status' { Show-Status }
    'run' {
      if (-not $Job) { throw '-Job uploader or -Job absorber is required.' }
      Start-ScheduledTask -TaskName "$LabelPrefix-$Job"
      "started: $LabelPrefix-$Job"
    }
    'uninstall' {
      foreach ($name in Get-TaskNames) {
        Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue
      }
      $left = @(Get-TaskNames | ForEach-Object { Get-ScheduledTask -TaskName $_ -ErrorAction SilentlyContinue })
      if ($left.Count) {
        $left | ForEach-Object { 'STILL THERE: ' + $_.TaskName }
        throw 'Some jobs were not removed.'
      }
      'removed: both scheduled jobs are gone'
    }
    'notify-test' {
      $title = if ($env:TP_TITLE) { $env:TP_TITLE } else { 'Transcript pipeline' }
      $msg = if ($env:TP_MSG) { $env:TP_MSG } else { 'Test notification' }
      Show-Toast $title $msg
      'notification sent'
    }
  }
  exit 0
} catch {
  "ERROR: " + $_.Exception.Message
  exit 1
}
