<#
.SYNOPSIS
    Four-Folder Driver Management Script
.DESCRIPTION
    This script implements a driver management system using four folders:
      1. Native: Baseline, factory-installed drivers.
      2. Active: Currently active drivers.
      3. New: Drop zone for new driver update files.
      4. Archive: Stores older driver versions for rollback.
    
    The script enforces that only these folders contain driver files and logs every step.
    
.PARAMETER List
    Lists the driver files present in each of the four folders.
.PARAMETER Update
    Processes driver updates by comparing new driver files in the New folder with the Active drivers.
.PARAMETER Help
    Displays the help information.
.EXAMPLE
    .\DriverManagement.ps1 -List
    Lists the driver files in each folder.
.EXAMPLE
    .\DriverManagement.ps1 -Update
    Processes updates for manufacturers defined in config.json.
#>

[CmdletBinding()]
param (
    [switch]$List,
    [switch]$Update,
    [switch]$Help
)

# Ensure script execution is allowed
if ((Get-ExecutionPolicy) -eq "Restricted") {
    Write-Host "WARNING: PowerShell execution policy is restricted." -ForegroundColor Yellow
    Write-Host "Run 'Set-ExecutionPolicy RemoteSigned -Scope CurrentUser' to enable script execution." -ForegroundColor Yellow
    exit
}

# Define base directory and folder paths
$BaseDriverPath = "C:\DriverManagement"
$ConfigFile = Join-Path $BaseDriverPath "config.json"

# Ensure config file exists
if (-not (Test-Path $ConfigFile)) {
    Write-Host "ERROR: Config file missing at $ConfigFile. Run the install script first." -ForegroundColor Red
    exit
}

# Load configuration
$config = Get-Content $ConfigFile | ConvertFrom-Json
$NativeFolder   = Join-Path $config.basePath $config.folders.Native
$ActiveFolder   = Join-Path $config.basePath $config.folders.Active
$NewFolder      = Join-Path $config.basePath $config.folders.New
$ArchiveFolder  = Join-Path $config.basePath $config.folders.Archive
$LogFile        = Join-Path $config.basePath $config.logFile
$Manufacturers  = $config.manufacturers

# Function: Write log messages with timestamp
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp [$Level] $Message"
    Add-Content -Path $LogFile -Value $entry
    Write-Host $entry
}

# Function: Initialize required folders
function Initialize-FolderStructure {
    $folders = @($BaseDriverPath, $NativeFolder, $ActiveFolder, $NewFolder, $ArchiveFolder)
    foreach ($folder in $folders) {
        if (-not (Test-Path $folder)) {
            New-Item -Path $folder -ItemType Directory | Out-Null
            Write-Log "Created folder: $folder"
        }
    }
}

# Function: Extract version number from driver filename
function Extract-Version {
    param ([string]$FileName)
    if ($FileName -match "v([\d\.]+)") {
        return $matches[1]
    }
    return $null
}

# Function: Compare two versions (returns -1, 0, 1)
function Compare-Versions {
    param ([string]$version1, [string]$version2)
    try {
        $v1 = [version]$version1
        $v2 = [version]$version2
        return $v1.CompareTo($v2)
    } catch {
        Write-Log "Version comparison failed: $_" "ERROR"
        return 0
    }
}

# Function: List driver files in a given folder
function List-DriverFiles {
    param ([string]$Folder)
    Get-ChildItem -Path $Folder -Filter "*_Driver_v*.exe" -File | Select-Object Name, FullName
}

# Function: Process a driver update for a specific manufacturer
function Process-DriverUpdate {
    param ([string]$Manufacturer)
    
    Write-Log "Processing updates for manufacturer: $Manufacturer"
    
    $activeFile = Get-ChildItem -Path $ActiveFolder -Filter "$Manufacturer`_Driver_v*.exe" -File | Select-Object -First 1
    $activeVersion = $null
    if ($activeFile) {
        $activeVersion = Extract-Version $activeFile.Name
        Write-Log "Active driver: $($activeFile.Name) (Version: $activeVersion)"
    } else {
        Write-Log "No active driver found. Using native as fallback."
        $activeFile = Get-ChildItem -Path $NativeFolder -Filter "$Manufacturer`_Driver_v*.exe" -File | Select-Object -First 1
        if ($activeFile) {
            $activeVersion = Extract-Version $activeFile.Name
            Copy-Item -Path $activeFile.FullName -Destination $ActiveFolder
        } else {
            Write-Log "No driver available for $Manufacturer. Skipping update." "ERROR"
            return
        }
    }

    $newFile = Get-ChildItem -Path $NewFolder -Filter "$Manufacturer`_Driver_v*.exe" -File | Select-Object -First 1
    if (-not $newFile) {
        Write-Log "No new driver file found for $Manufacturer."
        return
    }

    $newVersion = Extract-Version $newFile.Name
    Write-Log "New driver found: $($newFile.Name) (Version: $newVersion)"
    
    $comparison = Compare-Versions -version1 $activeVersion -version2 $newVersion
    if ($comparison -ge 0) {
        Write-Log "Active driver is up-to-date or newer. No update needed."
        return
    }

    $response = Read-Host "Update available for $Manufacturer (New: $newVersion). Proceed? (Y/N)"
    if ($response -notmatch '^[Yy]') {
        Write-Log "User declined update for $Manufacturer."
        return
    }

    Write-Log "Creating system restore point (simulation)..."
    
    if ($activeFile) {
        Move-Item -Path $activeFile.FullName -Destination $ArchiveFolder -Force
        Write-Log "Moved active driver $($activeFile.Name) to Archive."
    }

    Move-Item -Path $newFile.FullName -Destination $ActiveFolder -Force
    Write-Log "Updated $Manufacturer driver to $newVersion."

    # Force Windows to recognize the new driver
    pnputil /scan-devices | Out-Null
    Write-Log "Triggered Windows driver scan."
}

# Script Execution

Initialize-FolderStructure

if ($List) {
    Write-Host "`nNative Drivers:"; List-DriverFiles -Folder $NativeFolder; Write-Host ""
    Write-Host "Active Drivers:"; List-DriverFiles -Folder $ActiveFolder; Write-Host ""
    Write-Host "New Drivers:"; List-DriverFiles -Folder $NewFolder; Write-Host ""
    Write-Host "Archive Drivers:"; List-DriverFiles -Folder $ArchiveFolder; Write-Host ""
    exit
}

if ($Update) {
    foreach ($mfg in $Manufacturers) {
        Process-DriverUpdate -Manufacturer $mfg
    }
    exit
}

Write-Host "Usage: .\DriverManagement.ps1 -List | -Update | -Help"
