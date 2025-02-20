## This script configures the Realtek 8852CE WiFi 6E PCI-E NIC by:
##  - Backing up current registry settings to a file (with the adapter description as the first line)
##  - Updating the registry values to:
##       WifiProtocol_2g = 0
##       WifiProtocol_5g = 26
##       RegROAMSensitiveLevel = 127
##  - Restarting the network adapter
##  - Creating a flag file

$realtekAdapter = "Realtek 8852CE WiFi 6E PCI-E NIC"
$realtekSettings = @{
    "WifiProtocol_2g"        = "0"
    "WifiProtocol_5g"        = "26"
    "RegROAMSensitiveLevel"  = "127"
}

$backupDir = "C:\ProgramData\WiFiAdapterConfig"
$backupFilePath = "$backupDir\WiFiAdapterConfigBackup.txt"
#$flagFilePath = "$backupDir\WiFiAdapterConfigFlag.txt"

# Ensure the backup directory exists
if (-not (Test-Path $backupDir)) {
    New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
}

# Load a simple .NET helper class for registry access
Add-Type -TypeDefinition @"
using System;
using Microsoft.Win32;
public class RegHelper {
    public static string[] GetSubKeyNames(string path) {
        using (RegistryKey key = Registry.LocalMachine.OpenSubKey(path)) {
            return key.GetSubKeyNames();
        }
    }
    public static object GetValue(string path, string name) {
        using (RegistryKey key = Registry.LocalMachine.OpenSubKey(path)) {
            return key.GetValue(name);
        }
    }
}
"@

# Search for the registry subkey for the Realtek adapter
$baseKeyPath = "SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
$subKeys = [RegHelper]::GetSubKeyNames($baseKeyPath)
$regPath = $null

foreach ($subKey in $subKeys) {
    $keyPath = "$baseKeyPath\$subKey"
    if ([RegHelper]::GetValue($keyPath, "DriverDesc") -eq $realtekAdapter) {
        $regPath = "HKLM:\$keyPath"
        break
    }
}

if ($null -ne $regPath) {
    # Backup current registry settings if not already backed up.
    if (-not (Test-Path $backupFilePath)) {
        $backupContent = @()
        # Add adapter description as the first line
        $backupContent += $realtekAdapter
        foreach ($setting in $realtekSettings.Keys) {
            # Remove the "HKLM:" prefix before passing the path to GetValue
            $currentValue = [RegHelper]::GetValue($regPath.Substring(6), $setting)
            $backupContent += "$setting=$currentValue"
        }
        $backupContent | Out-File -FilePath $backupFilePath -Encoding UTF8
        Write-Output "Current registry values backed up successfully."
    }

    # Update the registry with the new settings
    foreach ($setting in $realtekSettings.Keys) {
        Set-ItemProperty -Path $regPath -Name $setting -Value $realtekSettings[$setting] -Type String
    }
    Write-Output "Registry values updated successfully."

    # Restart the network adapter
    $netAdapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -eq $realtekAdapter }
    if ($netAdapter) {
        Restart-NetAdapter -Name $netAdapter.Name -Confirm:$false
        Write-Output "Network adapter restarted successfully."
    }
    else {
        Write-Output "Failed to find network adapter to restart."
    }

    # Create the flag file
    #New-Item -Path $flagFilePath -ItemType File -Force | Out-Null
    #Write-Output "Flag file created successfully."
}
else {
    Write-Output "Network adapter not found."
}
