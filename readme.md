# NVIDIA GPU Power Manager

This PowerShell script allows you to manage the power limits of NVIDIA GPUs on your Windows system. It provides functionality to set custom power limits, create a scheduled task to apply these limits at login, and display current GPU power information.

## Features

- Set custom power limits for all NVIDIA GPUs on the system
- Create a scheduled task to apply power limits at login
- Display current GPU power information
- Remove the scheduled task and clean up the script

## Requirements

- Windows operating system
- PowerShell
- NVIDIA GPU(s) with nvidia-smi utility installed

## Usage

1. Run `run.bat` or execute `set_power.ps1` directly in PowerShell with administrative privileges.
2. The script will display current GPU power information.
3. Enter the desired GPU power percentage (1-100) when prompted.
4. The script will create a scheduled task and apply the new power limits immediately.

## Options

- Enter a number between 1 and 100 to set the GPU power percentage.
- Press Enter without input to use the default value of 100%.
- Enter 'q' to quit without making any changes.
- Enter 'u' to uninstall the scheduled task and remove the script.

## Files

- `set_power.ps1`: Main PowerShell script
- `run.bat`: Batch file to run the PowerShell script with administrative privileges

## Notes

- The script requires administrative privileges to function properly.
- It creates a scheduled task named "SetNvidiaGPUPower" to apply the power limits at login.
- The script is copied to `%LOCALAPPDATA%\SetNvidiaGPUPower\` for use by the scheduled task.

## Disclaimer

Use this script at your own risk. Modifying GPU power limits may affect system stability and performance. Ensure you understand the implications before making changes.
