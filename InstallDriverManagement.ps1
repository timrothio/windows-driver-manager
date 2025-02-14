<#
.SYNOPSIS
    Installation script for the Driver Management Tool.

.DESCRIPTION
    This script creates the base folder structure for the driver management tool:
      - Native
      - Active
      - New
      - Archive
    It also generates a sample configuration file (config.json) in the base directory.

.NOTES
    - Requires administrative privileges.
    - Modify the $BasePath variable as needed.
    - This script is intended for initial setup and should be pushed to version control.
#>

[CmdletBinding()]
param (
    [string]$BasePath = "C:\DriverManagement"
)

# Define subfolder names for the driver repository.
$folders = @{
    "Native"  = "Native"
    "Active"  = "Active"
    "New"     = "New"
    "Archive" = "Archive"
}

# Create the base folder if it does not exist.
if (-not (Test-Path $BasePath)) {
    New-Item -Path $BasePath -ItemType Directory | Out-Null
    Write-Host "Created base folder: $BasePath"
} else {
    Write-Host "Base folder already exists: $BasePath"
}

# Create subfolders.
foreach ($folder in $folders.Values) {
    $folderPath = Join-Path $BasePath $folder
    if (-not (Test-Path $folderPath)) {
        New-Item -Path $folderPath -ItemType Directory | Out-Null
        Write-Host "Created folder: $folderPath"
    } else {
        Write-Host "Folder already exists: $folderPath"
    }
}

# Create a sample configuration file.
$config = @{
    basePath       = $BasePath
    folders        = $folders
    manufacturers  = @("NVIDIA", "AMD", "Intel")
    driverFilePattern = "{manufacturer}_Driver_v*.exe"
    logFile        = "DriverManagement.log"
    apiEndpoints   = @{
        "NVIDIA" = "https://www.nvidia.com/Download/index.aspx"
        "AMD"    = "https://www.amd.com/en/support"
        "Intel"  = "https://www.intel.com/content/www/us/en/support/detect.html"
    }
    cleanupPolicy  = @{
        retainArchives = 2
    }
} | ConvertTo-Json -Depth 5

$configFilePath = Join-Path $BasePath "config.json"
$config | Out-File -FilePath $configFilePath -Encoding UTF8

Write-Host "`nInstallation complete. The following structure has been created under $BasePath:"
Get-ChildItem -Path $BasePath -Directory | ForEach-Object { Write-Host " - $($_.Name)" }
Write-Host "`nSample configuration file created at: $configFilePath"
