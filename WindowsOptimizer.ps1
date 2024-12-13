# Functions
function Start-SplashScreen {
    param (
        [parameter(Mandatory = $true, HelpMessage = "Specify the processes by name and powershell-command or https-link. ")]
        [array]$Processes,
        
        [parameter(Mandatory = $false, HelpMessage = "Main message on the Splash Screen.")]
        [string]$MessageHeader = "Windows Preperation",
        
        [parameter(Mandatory = $false, HelpMessage = "Initla message where the script names will show on the Splash Screen (should appear less than a second).")]
        [string]$MessageText = "Initiate Installation",
        
        [parameter(Mandatory = $false, HelpMessage = "Initla status idendicator on the Splash Screen (should appear less than a second).")]
        [string]$MessageStatus = "...",

        [parameter(Mandatory = $false, HelpMessage = "Finishing message befor Splash Screen closes")]
        [string]$MessageFinished = "All processes finished. This window closes automatically. ", 

        [parameter(Mandatory = $false, HelpMessage = "Time until Splash Screen closes after finishing")]
        [int]$ClosingTimer = 5,

        [parameter(Mandatory = $false, HelpMessage = "Background color of the Splash Screen. Eg. #CCf4f4f4 (CC = 80% transparent) or #f4f4f4")]
        [string]$ColorBackground = "#f4f4f4", 

        [parameter(Mandatory = $false, HelpMessage = "Text color of the Splash Screen. Eg. #161616")]
        [string]$ColorText = "#161616"

    )


    Add-Type -AssemblyName PresentationFramework
    [XML]$xaml = @"
<Window 
  xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
  xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
  Title="$MessageHeader"
  WindowStartupLocation="CenterScreen"
  WindowStyle="None"
  AllowsTransparency="True"
  WindowState="Maximized"
  ShowInTaskbar="False" 
  Background="$ColorBackground"
  Foreground="$ColorText"
  >
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="*"/>
      <RowDefinition Height="75"/>
    </Grid.RowDefinitions>
    <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
      <TextBlock Name="TextMessageHeader" Text="$MessageHeader" FontSize="32" FontWeight="Bold" TextAlignment="Center" />
      <TextBlock Name="TextMessageBody" Text="$MessageText" FontSize="16" TextWrapping="Wrap" TextAlignment="Center" FontStyle="Italic" Margin="0,20,0,20" />
      <TextBlock Name="TextMessageStatus" Text="$MessageStatus" FontSize="18" FontWeight="Bold" TextAlignment="Center"/>
    </StackPanel>
    <Button Grid.Row="1" Name="ShowTerminal" Content="" HorizontalAlignment="Stretch" Background="Transparent" BorderThickness="0" />
  </Grid>
</Window>
"@
    <#

    #>
    # Load XAML
    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    $Window = [Windows.Markup.XamlReader]::Load($reader)

    # Create a DispatcherTimer for the "Later" button action
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMinutes(15)
    $timer.Add_Tick({
        $timer.Stop()
        $Window.Show()
    }) 

    $messageScreenText = $Window.FindName("TextMessageBody")
    $messageScreenStatus = $Window.FindName("TextMessageStatus")

    $ShowTerminalButton = $Window.FindName("ShowTerminal")
    $ShowTerminalButton.Add_Click({ Show-Console })

    # Credits to - http://powershell.cz/2013/04/04/hide-and-show-console-window-from-gui/
    Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);

[DllImport("user32.dll")]
[return: MarshalAs(UnmanagedType.Bool)]
public static extern bool SetForegroundWindow(IntPtr hWnd);
'

    function Show-Console {
        $consolePtr = [Console.Window]::GetConsoleWindow()
        [Console.Window]::ShowWindow($consolePtr, 5)
        [Console.Window]::SetForegroundWindow($consolePtr) # Bring the window to the front
    }

    function Hide-Console {
        $consolePtr = [Console.Window]::GetConsoleWindow()
        [Console.Window]::ShowWindow($consolePtr, 0)
    }

    # Show the window
    #Hide-Console
    $Window.Show() | Out-Null

    $counter = 0 
    $total = $Processes.Count
    foreach ($script in $Processes) {
        $counter++
        $messageScreenText.Text = "$($script.Name)"
        $messageScreenStatus.Text = "($counter/$total)"

        $Window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [System.Action]{})

        # Check if the value is a URL (starts with "http") 
        if ($script.Script -match "^https?://" -or $script.Script -match "^http://" -or $script.Script -match "^ftp://") {
            Write-Output "($counter/$total) - Running online script: $($script.Script)"

            # Download the script and run it
            if (-NOT (Test-WebConnection "$($script.Script)")) {Write-Warning "Script not available: $($script.Script)"; continue}
            $WebClient = New-Object System.Net.WebClient
            $WebPSCommand = $WebClient.DownloadString("$($script.Script)")
            Invoke-Expression -Command $WebPSCommand
            $WebClient.Dispose()

        } else {
        # Directly run the command (assuming it's a string)
        Write-Output "($counter/$total)- Running PowerShell command: $($script.Script)"
        Invoke-Expression $($script.Script)
        }
    }

    # Update the UI with the final message and countdown timer
    $messageScreenText.Text = $MessageFinished

    # Countdown loop
    for ($i = $ClosingTimer; $i -gt 0; $i--) {
        $messageScreenStatus.Text = "$i Seconds"

        # Update the UI
        $Window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [System.Action]{})
        
        # Wait for 1 second
        Start-Sleep -Seconds 1
    }

    # Close the window after the countdown
    $Window.Close()

    Show-Console
}

function Start-Debloat {
    & ([scriptblock]::Create((Invoke-RestMethod "https://raw.githubusercontent.com/Raphire/Win11Debloat/master/Get.ps1"))) -Silent -RemoveApps -RemoveW11Outlook -RemoveCommApps -DisableDVR -ForceRemoveEdge -DisableBing -DisableTelemetry -ShowKnownFileExt -DisableSuggestions -DisableLockscreenTips -TaskbarAlignLeft -HideDupliDrive -HideChat -DisableCopilot -DisableRecall -Hide3dObjects -DisableWidgets
    Write-Output "Debloated Windows"
}

function Add-Folders {
    New-Item -Path "$env:APPDATA\WindowsOptimization" -ItemType Directory -Force
}

function Clear-Shaders {

    $cleanupScriptContent = @"
# Perform the cleanup operation
$targetPath = "$env:USERPROFILE\AppData\LocalLow\NVIDIA\PerDriverVersion\DXCache\*"
try {
    Remove-Item -Path $targetPath -Recurse -Force -ErrorAction Stop
    "Cleanup successful. Deleted files from $targetPath." | Out-File -FilePath $outputFile -Append
} catch {
    "Error during cleanup: $($_.Exception.Message)" | Out-File -FilePath $outputFile -Append
}
"@

    # Save the cleanup script to a file
    $cleanupScriptPath = "$env:APPDATA\WindowsOptimization\CleanupDxShaders.ps1"
    Set-Content -Path $cleanupScriptPath -Value $cleanupScriptContent

    # Create a COM object for Task Scheduler
    $taskScheduler = New-Object -ComObject "Schedule.Service"
    try {
        $taskScheduler.Connect()
    } catch {
        Write-Error "Failed to connect to the Task Scheduler service. Ensure the script is run with sufficient permissions."
        return
    }

    # Get the root folder of the Task Scheduler
    try {
        $rootFolder = $taskScheduler.GetFolder("\")
    } catch {
        Write-Error "Failed to retrieve the root folder. Check if Task Scheduler service is running."
        return
    }

    # Create a new task definition
    $taskDefinition = $taskScheduler.NewTask(0)  # 0 means create a new task

    # Set task properties (enabled and available to run)
    $taskDefinition.Settings.Enabled = $true
    $taskDefinition.Settings.Hidden = $false
    $taskDefinition.Settings.StartWhenAvailable = $true

    # Define the logon trigger (trigger task when a user logs on)
    $trigger = $taskDefinition.Triggers.Create(1)  # 1 represents a logon trigger
    $trigger.StartBoundary = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")  # Set start boundary to current date and time

    # Define the action (what the task will do, in this case, run the cleanup script)
    $action = $taskDefinition.Actions.Create(0)  # 0 means "execute a program"
    $action.Path = "powershell.exe"  # Path to PowerShell executable
    $action.Arguments = "-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File $cleanupScriptPath"  # Arguments to run the cleanup script

    # Register the task (this adds the task to the Task Scheduler)
    $taskName = "Clean DirectX Shaders"  # Define the task name
    try {
        $rootFolder.RegisterTaskDefinition(
            $taskName,  # Task name
            $taskDefinition,  # Task definition object
            6,  # 6 means "Create or Replace" if the task already exists
            "",  # No username (default system account)
            "",  # No password
            3   # 3 means "Logon interactive"
        )
    } 
    catch {
        Write-Error "Failed to register the task. Ensure the parameters are correct."
    }

    Write-Output "Scheduled task '$taskName' created successfully."
}

function Set-HighPerformance {
    powercfg -setactive SCHEME_MIN
}

# Main

# Check if running as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    # Create a new process to relaunch the script with Administrator privileges
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "powershell.exe"
    $processInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File \$($MyInvocation.MyCommand.Path)"
    $processInfo.Verb = "runas" # This specifies that it should be run as Administrator

    try {
        # Start the new process
        [System.Diagnostics.Process]::Start($processInfo) | Out-Null
    } catch {
        Write-Error "Failed to start the script as Administrator. User may have canceled the UAC prompt."
    }

    # Exit the current process
    exit
}

$processes = @(
  @{
    Name = "Debloating Windows"
    Script = "Start-Debloat"
  },
  @{
    Name = "Adding Folder Windows Optimization"
    Script = "Add-Folders"
  },
  @{
    Name = "Setting up automatic DirectX Shader Cleaner"
    Script = "Clear-Shaders"
  },
  @{
    Name = "Setting the Power Performance to High Performance"
    Script = "Set-HighPerformance"
  },
  @{
    Name = "Windows Quality Updates"
    Script = "https://raw.githubusercontent.com/FlorianSLZ/OSDCloud-Stuff/main/OOBE/Windows-Updates_Quality.ps1"
  },
  @{
    Name = "Windows Firmware and Driver Updates"
    Script = "https://raw.githubusercontent.com/FlorianSLZ/OSDCloud-Stuff/main/OOBE/Windows-Updates_DriverFirmware.ps1"
  }
)

Start-SplashScreen -Processes $processes -MessageHeader "Optimizing Windows"