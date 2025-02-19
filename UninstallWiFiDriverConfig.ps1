## This script restores the original registry values for the Realtek 8852CE WiFi 6E PCI-E NIC or MediaTek Wi-Fi 6 MT7921 Wireless LAN Card network adapters
# by reading the backup configuration file and setting the registry values to the ones in the backup.
# It then removes the installation folder.

# Define the path for the backup file and the flag file
$backupDir = "C:\ProgramData\WiFiAdapterConfig"
$backupFilePath = "$backupDir\WiFiAdapterConfigBackup.txt"
#$flagFilePath = "$backupDir\WiFiAdapterConfigFlag.txt"

# Load the .NET Registry class using a uniquely named type to avoid conflicts
if (-not ([System.Management.Automation.PSTypeName]'RegHelperUninstall').Type) {
    Add-Type -TypeDefinition @"
using System;
using Microsoft.Win32;
public class RegHelperUninstall {
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
    public static void SetValue(string path, string name, object value) {
        using (RegistryKey key = Registry.LocalMachine.OpenSubKey(path, true)) {
            key.SetValue(name, value);
        }
    }
}
"@
}

# Check if the backup file exists
if (Test-Path $backupFilePath) {
    # Read the backup configuration
    $backupContent = Get-Content -Path $backupFilePath
    $adapterDesc = $null
    $adapterSettings = @{ }

    foreach ($line in $backupContent) {
        if ($line -match "^(Realtek 8852CE WiFi 6E PCI-E NIC|MediaTek Wi-Fi 6 MT7921 Wireless LAN Card)$") {
            $adapterDesc = $line
        } elseif ($adapterDesc -and $line -match "^(.*)=(.*)$") {
            $setting, $value = $line -split "="
            $adapterSettings[$setting] = $value
        }
    }

    if ($adapterDesc -and $adapterSettings.Count -gt 0) {
        # Get all subkeys under the base registry path
        $subKeys = [RegHelperUninstall]::GetSubKeyNames("SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}")

        # Initialize a variable to store the correct registry path
        $regPath = $null

        # Loop through each subkey to find the correct network adapter
        foreach ($subKey in $subKeys) {
            $keyPath = "SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}\$subKey"
            if ([RegHelperUninstall]::GetValue($keyPath, "DriverDesc") -eq $adapterDesc) {
                $regPath = $keyPath
                break
            }
        }

        if ($null -ne $regPath) {
            # Restore the registry values
            foreach ($setting in $adapterSettings.Keys) {
                [RegHelperUninstall]::SetValue($regPath, $setting, $adapterSettings[$setting])
            }
            Write-Output "Registry values restored successfully."

            # Get the network adapter name
            $netAdapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -eq $adapterDesc }
            if ($netAdapter) {
                # Restart the network adapter
                Restart-NetAdapter -Name $netAdapter.Name -Confirm:$false
                Write-Output "Network adapter restarted successfully."
            } else {
                Write-Output "Failed to find network adapter to restart."
            }

            # Remove the entire backup folder
            Remove-Item -Path $backupDir -Recurse -Force
            Write-Output "Backup folder removed successfully."
        } else {
            Write-Output "Network adapter not found."
        }
    } else {
        Write-Output "Invalid backup configuration."
    }
} else {
    Write-Output "Backup file not found."
}
