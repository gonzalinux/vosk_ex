# PowerShell script to download Vosk library for Windows
param(
    [string]$Version = "0.3.45",
    [string]$TargetDir = "priv\native\windows-x86_64"
)

$ErrorActionPreference = "Stop"

$downloadUrl = "https://github.com/alphacep/vosk-api/releases/download/v$Version/vosk-win64-$Version.zip"
$tempZip = Join-Path $env:TEMP "vosk-win64-$Version.zip"
$tempExtract = Join-Path $env:TEMP "vosk_extract"
$targetDll = Join-Path $TargetDir "libvosk.dll"

# Check if already downloaded (both DLL and LIB for MSVC)
$targetLib = Join-Path $TargetDir "libvosk.lib"
if ((Test-Path $targetDll) -and (Test-Path $targetLib)) {
    Write-Host "Vosk library already exists at: $targetDll"
    exit 0
}

Write-Host ""
Write-Host "================================================"
Write-Host "Downloading Vosk library for Windows x64..."
Write-Host "================================================"
Write-Host ""
Write-Host "URL: $downloadUrl"

# Ensure target directory exists
if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

# Download with progress
Write-Host "Downloading..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip

# Extract
Write-Host "Extracting..."
if (Test-Path $tempExtract) {
    Remove-Item -Path $tempExtract -Recurse -Force
}
Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

# Find and copy library files
$extractedDir = Get-ChildItem -Path $tempExtract -Directory | Select-Object -First 1
Write-Host "Found library in: $($extractedDir.FullName)"

# Copy main DLL
Copy-Item -Path "$($extractedDir.FullName)\libvosk.dll" -Destination $targetDll -Force
Write-Host "Copied: libvosk.dll"

# Copy MinGW runtime DLLs (required dependencies)
$runtimeDlls = @("libgcc_s_seh-1.dll", "libstdc++-6.dll", "libwinpthread-1.dll")
foreach ($dll in $runtimeDlls) {
    $sourceDll = Join-Path $extractedDir.FullName $dll
    if (Test-Path $sourceDll) {
        $targetRuntimeDll = Join-Path $TargetDir $dll
        Copy-Item -Path $sourceDll -Destination $targetRuntimeDll -Force
        Write-Host "Copied: $dll (MinGW runtime)"
    }
}

# Copy .lib file if it exists (needed for MSVC linking)
$libFile = Join-Path $extractedDir.FullName "libvosk.lib"
if (Test-Path $libFile) {
    $targetLib = Join-Path $TargetDir "libvosk.lib"
    Copy-Item -Path $libFile -Destination $targetLib -Force
    Write-Host "Copied: libvosk.lib (MSVC import library)"
} else {
    Write-Host "Warning: libvosk.lib not found - will create from DLL"
    # Generate .lib from .dll using lib.exe if available
    $libExe = where.exe lib.exe 2>$null
    if ($libExe) {
        $defFile = Join-Path $env:TEMP "libvosk.def"
        $targetLib = Join-Path $TargetDir "libvosk.lib"

        # Use dumpbin to get exports and create .def file
        Write-Host "Generating import library from DLL..."
        & dumpbin /EXPORTS "$targetDll" | Out-File -FilePath "$env:TEMP\exports.txt"

        # Create .lib using lib.exe with /DEF (simpler approach)
        & lib.exe /DEF /OUT:"$targetLib" /MACHINE:X64 /NAME:"$targetDll"

        if (Test-Path $targetLib) {
            Write-Host "Generated: libvosk.lib"
        } else {
            Write-Host "Could not generate import library - you may need to link differently"
        }
    } else {
        Write-Host "lib.exe not found - cannot generate import library"
        Write-Host "Compilation with MSVC may fail - consider using MinGW instead"
    }
}

# Cleanup
Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
Remove-Item -Path $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Library installed to: $TargetDir"
Write-Host ""
