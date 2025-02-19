## This script checks for the existence of the Realtek 8852CE WiFi 6E PCI-E NIC or MediaTek Wi-Fi 6 MT7921 Wireless LAN Card network adapters
# by searching the registry for the adapter's description. If the adapter is found, it updates the following configuration settings for the Wi-Fi adapter in the registry:
# For Realtek 8852CE WiFi 6E PCI-E NIC:
# - Disable 2.4 Ghz
# - Change 5 Ghz mode to IEEE 802.11a/n/nc
# - Disable "Roaming Sensitivity Level"
#
# It then restarts the network adapter to apply the changes.

# Define the adapter descriptions and their respective registry settings
$adapters = @{
    "Realtek 8852CE WiFi 6E PCI-E NIC" = @{
        "WifiProtocol_2g" = "0"
        "WifiProtocol_5g" = "26"
        "RegROAMSensitiveLevel" = "127"
    }
    "MediaTek Wi-Fi 6 MT7921 Wireless LAN Card" = @{
        "Band Selection" = "2"
        "RoamIndicateTh" = "2"
        "CurrPhyMode" = "1"
    }
}

# Define the path for the backup file and the flag file
$backupDir = "C:\ProgramData\WiFiAdapterConfig"
$backupFilePath = "$backupDir\WiFiAdapterConfigBackup.txt"
$flagFilePath = "$backupDir\WiFiAdapterConfigFlag.txt"

# Ensure the directory exists
if (-not (Test-Path $backupDir)) {
    New-Item -Path $backupDir -ItemType Directory -Force
}

# Load the .NET Registry class
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

# Get all subkeys under the base registry path
$subKeys = [RegHelper]::GetSubKeyNames("SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}")

# Initialize a variable to store the correct registry path and adapter settings
$regPath = $null
$adapterSettings = $null

# Loop through each subkey to find the correct network adapter
foreach ($subKey in $subKeys) {
    $keyPath = "SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}\$subKey"
    foreach ($adapterDesc in $adapters.Keys) {
        if ([RegHelper]::GetValue($keyPath, "DriverDesc") -eq $adapterDesc) {
            $regPath = "HKLM:\$keyPath"
            $adapterSettings = $adapters[$adapterDesc]
            break
        }
    }
    if ($regPath) { break }
}

if ($null -ne $regPath) {
    # Backup current registry values
    if (-not (Test-Path $backupFilePath)) {
        $backupContent = @()
        foreach ($setting in $adapterSettings.Keys) {
            $currentValue = [RegHelper]::GetValue($regPath.Substring(5), $setting)
            $backupContent += "$setting=$currentValue"
        }
        $backupContent | Out-File -FilePath $backupFilePath
        Write-Output "Current registry values backed up successfully."
    }

    # Update the registry values
    foreach ($setting in $adapterSettings.Keys) {
        Set-ItemProperty -Path $regPath -Name $setting -Value $adapterSettings[$setting] -Type String
    }
    Write-Output "Registry values updated successfully."
    
    # Get the network adapter name
    $netAdapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -eq $adapterDesc }
    if ($netAdapter) {
        # Restart the network adapter
        Restart-NetAdapter -Name $netAdapter.Name -Confirm:$false
        Write-Output "Network adapter restarted successfully."
    } else {
        Write-Output "Failed to find network adapter to restart."
    }

    # Create a flag file for the detection rule
    New-Item -Path $flagFilePath -ItemType File -Force
    Write-Output "Flag file created successfully."
} else {
    Write-Output "Network adapter not found."
}