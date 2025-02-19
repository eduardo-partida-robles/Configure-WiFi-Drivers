# WiFi Driver Configuration Scripts

This repository contains PowerShell scripts to configure and restore settings for specific WiFi network adapters.

## Scripts

### InstallWiFiDriverConfig.ps1

This script checks for the existence of the Realtek 8852CE WiFi 6E PCI-E NIC or MediaTek Wi-Fi 6 MT7921 Wireless LAN Card network adapters. If the adapter is found,it creates a backup of the current configuration and then it updates the following configuration settings in the registry:

  - Disable 2.4 GHz
  - Change 5 GHz mode to IEEE 802.11a/n/nc
  - Disable "Roaming Sensitivity Level"

The script then restarts the network adapter to apply the changes.

### UninstallWiFiDriverConfig.ps1

This script restores the original registry values for the Realtek 8852CE WiFi 6E PCI-E NIC or MediaTek Wi-Fi 6 MT7921 Wireless LAN Card network adapters by reading the backup configuration file and setting the registry values to the ones in the backup. It then removes the backup directory.

## Usage

1. **Install Configuration**:
   Run `InstallWiFiDriverConfig.ps1` to apply the configuration settings to the WiFi adapters.

   ```powershell
   .\InstallWiFiDriverConfig.ps1
