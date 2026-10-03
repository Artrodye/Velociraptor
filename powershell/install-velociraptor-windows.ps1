[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$MsiPath = "C:\Temp\velociraptor-windows-lab.msi",

    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\Temp\velociraptor-install.log"
)

$ErrorActionPreference = "Stop"

function Get-VelociraptorService {
    Get-Service -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -match "velociraptor" -or
            $_.DisplayName -match "velociraptor"
        } |
        Select-Object -First 1
}

Write-Host "[*] Checking Velociraptor installation..."

$service = Get-VelociraptorService

if (-not $service) {

    if (-not (Test-Path $MsiPath)) {
        throw "MSI not found: $MsiPath"
    }

    Write-Host "[*] Velociraptor is not installed."
    Write-Host "[*] Installing from $MsiPath"

    $arguments = @(
        "/i"
        "`"$MsiPath`""
        "/qn"
        "/norestart"
        "/L*v"
        "`"$LogPath`""
    )

    $process = Start-Process `
        -FilePath "msiexec.exe" `
        -ArgumentList $arguments `
        -Wait `
        -PassThru

    if ($process.ExitCode -notin @(0, 3010)) {
        throw "MSI installation failed. Exit code: $($process.ExitCode)"
    }

    Write-Host "[+] Installation complete."
}
else {
    Write-Host "[=] Velociraptor already installed. Installation skipped."
}

$service = Get-VelociraptorService

if (-not $service) {
    throw "Velociraptor service was not found after installation."
}

Write-Host "[*] Service: $($service.Name)"

if ($service.StartType -ne "Automatic") {
    Write-Host "[*] Setting service startup type to Automatic."
    Set-Service -Name $service.Name -StartupType Automatic
}

$service.Refresh()

if ($service.Status -ne "Running") {
    Write-Host "[*] Starting Velociraptor service."
    Start-Service -Name $service.Name
}

$service = Get-Service -Name $service.Name

Write-Host "[+] Velociraptor status:"
$service | Format-Table Name, Status, StartType

Write-Host "[+] Done."
