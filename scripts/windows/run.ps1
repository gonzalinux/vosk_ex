# Windows helper script for VoskEx
# Adds Vosk DLLs to PATH before running Mix commands
#
# Usage from your project root:
#   .\scripts\windows\run.ps1 mix test
#   .\scripts\windows\run.ps1 mix run
#   .\scripts\windows\run.ps1 iex -S mix
#
# This script is an example for projects that use VoskEx as a dependency.

# Detect if running from dependency or main project
$ProjectRoot = Get-Location
$VoskDllPath = Join-Path $ProjectRoot "_build\dev\lib\vosk_ex\priv\native\windows-x86_64"

# Fallback: check if we're in the vosk_ex project itself
if (-not (Test-Path $VoskDllPath)) {
    $ScriptDir = Split-Path -Parent $PSCommandPath
    $ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..\..")
    $VoskDllPath = Join-Path $ProjectRoot "_build\dev\lib\vosk_ex\priv\native\windows-x86_64"
}

if (Test-Path $VoskDllPath) {
    $env:PATH = "$VoskDllPath;$env:PATH"
    Write-Host "[VoskEx] Added DLLs to PATH: $VoskDllPath" -ForegroundColor Green
} else {
    Write-Host "[VoskEx] WARNING: DLLs not found at $VoskDllPath" -ForegroundColor Yellow
    Write-Host "[VoskEx] Run 'mix deps.compile' or 'mix compile' first" -ForegroundColor Yellow
}

# Run the provided command
if ($args.Count -gt 0) {
    & $args[0] $args[1..($args.Count)]
} else {
    Write-Host ""
    Write-Host "Usage: .\scripts\windows\run.ps1 COMMAND"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\scripts\windows\run.ps1 mix test"
    Write-Host "  .\scripts\windows\run.ps1 mix run"
    Write-Host "  .\scripts\windows\run.ps1 iex -S mix"
}
