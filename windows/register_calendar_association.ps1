$ErrorActionPreference = 'Stop'

$appPath = Join-Path $PSScriptRoot 'calendar.exe'
if (-not (Test-Path $appPath)) {
  throw "calendar.exe was not found beside this script: $appPath"
}

$classes = 'HKCU:\Software\Classes'
$progId = 'CalendarApp.ics'
$extensionKey = Join-Path $classes '.ics\OpenWithProgids'
$progIdKey = Join-Path $classes $progId
$commandKey = Join-Path $progIdKey 'shell\open\command'
$supportedTypesKey = Join-Path $classes 'Applications\calendar.exe\SupportedTypes'

New-Item -Path $extensionKey -Force | Out-Null
New-ItemProperty -Path $extensionKey -Name $progId -Value '' -PropertyType String -Force | Out-Null
New-Item -Path $commandKey -Force | Out-Null
Set-Item -Path $commandKey -Value "`"$appPath`" `"%1`""
New-Item -Path $supportedTypesKey -Force | Out-Null
New-ItemProperty -Path $supportedTypesKey -Name '.ics' -Value '' -PropertyType String -Force | Out-Null

Write-Output 'Calendar is now available in the Open with list for .ics files.'
