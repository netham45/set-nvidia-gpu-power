$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Requesting administrative privileges..."
    Start-Process powershell.exe "-File `"$PSCommandPath`"" -Verb RunAs
    exit
}

function Show-GPUInfo {
    $gpuInfo = & nvidia-smi --query-gpu=gpu_name,power.draw,power.limit,power.max_limit,temperature.gpu --format=csv,noheader | 
        ConvertFrom-Csv -Header 'GPU Name','Power Draw','Power Limit','Max Power Limit','GPU Temp' | 
        ForEach-Object { 
            $powerLimitValue = [float]($_.('Power Limit') -replace ' W', '')
            $maxPowerLimitValue = [float]($_.('Max Power Limit') -replace ' W', '')
            $percentage = [math]::Round(($powerLimitValue / $maxPowerLimitValue) * 100, 2)
            $_ | Add-Member -MemberType NoteProperty -Name 'Percentage' -Value "$percentage%" -PassThru 
        }
    $gpuInfo | Format-Table -AutoSize
}

function Set-GPUPower {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateRange(1,100)]
        [int]$Percentage
    )

    foreach ($gpu in (& nvidia-smi -L)) {
        $gpuIndex = $gpu -replace '.*GPU (\d+).*', '$1'
        $maxPowerLimit = [int](& nvidia-smi -i $gpuIndex --query-gpu=power.max_limit --format=csv,noheader,nounits)
        $newPowerLimit = $maxPowerLimit * ($Percentage / 100)
        Write-Host "Setting GPU $gpuIndex power limit to $newPowerLimit W ($Percentage% of $maxPowerLimit W)"
        & nvidia-smi -i $gpuIndex -pl $newPowerLimit
    }

    Write-Host "Power limits have been set to $Percentage% for all GPUs."
}

function Create-ScheduledTask {
    param (
        [int]$Percentage
    )

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -File `"$env:LOCALAPPDATA\SetNvidiaGPUPower\set-nvidia-gpu-power.ps1`" -Percentage $Percentage"
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId (Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty UserName) -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

    Register-ScheduledTask -TaskName "SetNvidiaGPUPower" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
}

function Remove-ScheduledTask {
    Unregister-ScheduledTask -TaskName "SetNvidiaGPUPower" -Confirm:$false
    Remove-Item -Path "$env:LOCALAPPDATA\SetNvidiaGPUPower" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Scheduled task 'SetNvidiaGPUPower' has been removed and the script has been deleted from AppData."
}

Write-Host "This will create a scheduled task to set the power level for all NVIDIA GPUs on the system at login."
Write-Host "It will also set them immediately."
Write-Host ""

Write-Host "Current GPU Power information:"
Show-GPUInfo

do {
    $GPU_POWER = Read-Host "Enter the GPU power percentage (1-100, default: 100, q to quit, u to uninstall the task)"

    if ($GPU_POWER -eq 'q') { exit }
    if ($GPU_POWER -eq 'u') {
        Remove-ScheduledTask
        exit
    }
    if ($GPU_POWER -eq '') { $GPU_POWER = 100 }

    if ($GPU_POWER -match '^\d+$' -and [int]$GPU_POWER -ge 1 -and [int]$GPU_POWER -le 100) {
        $GPU_POWER = [int]$GPU_POWER
        break
    }
    Write-Host "Invalid input. Please enter a number between 1 and 100, or 'q' to quit with no change."
} while ($true)

if (-not (Test-Path "$env:LOCALAPPDATA\SetNvidiaGPUPower")) {
    New-Item -ItemType Directory -Path "$env:LOCALAPPDATA\SetNvidiaGPUPower" | Out-Null
}

$scriptContent = @"
param (
    [Parameter(Mandatory=`$true)]
    [ValidateRange(1,100)]
    [int]`$Percentage
)

foreach (`$gpu in (& nvidia-smi -L)) {
    `$gpuIndex = `$gpu -replace '.*GPU (\d+).*', '`$1'
    `$maxPowerLimit = [int](& nvidia-smi -i `$gpuIndex --query-gpu=power.max_limit --format=csv,noheader,nounits)
    `$newPowerLimit = `$maxPowerLimit * (`$Percentage / 100)
    Write-Host "Setting GPU `$gpuIndex power limit to `$newPowerLimit W (`$Percentage% of `$maxPowerLimit W)"
    & nvidia-smi -i `$gpuIndex -pl `$newPowerLimit
}

Write-Host "Power limits have been set to `$Percentage% for all GPUs."
"@

Set-Content -Path "$env:LOCALAPPDATA\SetNvidiaGPUPower\set-nvidia-gpu-power.ps1" -Value $scriptContent

Create-ScheduledTask -Percentage $GPU_POWER

Start-ScheduledTask -TaskName "SetNvidiaGPUPower"

# Wait for the scheduled task to finish
while (($task = Get-ScheduledTask -TaskName "SetNvidiaGPUPower" -ErrorAction SilentlyContinue) -and $task.State -ne "Ready") {
    Start-Sleep -Seconds 1
}

cls
Write-Host "New GPU Power information:"
Show-GPUInfo

Read-Host "Press Enter to exit"
