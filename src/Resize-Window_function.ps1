<#
.SYNOPSIS
    Resize-Window - Resizes a window.
    
    Resizes a window to a standard resolution based on
    its title, without direct DLL calls.

.LINK
    Get-WindowTitle, Resize-Window, KillAll-Window, Clolse-Window

    Get-WindowTitle.ps1 - PowerShell Team
    https://devblogs.microsoft.com/powershell/get-windowtitle-ps1/

.DESCRIPTION
    This function finds an open window by its title
    (wildcards are supported) and resizes it to a specified
    standard resolution (e.g., 720p, 1080p).
    
    It uses the .NET UI Automation framework to programmatically
    control the window's dimensions. This method avoids direct
    P/Invoke calls to user32.dll, making it a more modern approach
    for UI manipulation in PowerShell.

.PARAMETER WindowTitle
    The title of the window to resize. Wildcards (*) are supported
    to allow for partial matches.
    
    For example, "*Notepad" will match any window title ending
    with "Notepad".

.PARAMETER Resolution
    Specifies a standard resolution to apply to the window.
    This is a convenient shortcut for setting a specific width and height.
    Accepted values are: '480p', '720p', '1080p', '1440p', '4K'.

.EXAMPLE
    PS C:\> Resize-Window -WindowTitle "*Notepad" -Resolution '720p'

    Description:
    This command finds the first window with a title ending in "Notepad"
    and resizes it to 1280x720 pixels.

.EXAMPLE
    PS C:\> Resize-Window -WindowTitle "Calculator" -Resolution '480p' -Verbose

    Description:
    This command finds the "Calculator" window, resizes it to 854x480 pixels,
    and provides detailed information about the steps being taken.

.NOTES
    - The target window must be open and visible for the script to find it.
    - If multiple windows match the title, the script will resize the first one it finds.
    - This function requires the .NET UI Automation libraries, which are standard on modern Windows systems.
#>
function Resize-Window {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, HelpMessage = "The title of the window to resize. Wildcards are supported.")]
        [string]$WindowTitle = "PowerShell",

        [Parameter(Mandatory = $false, HelpMessage = "Select a standard resolution.")]
        [ValidateSet('480p', '720p', '1080p', '1440p', '4K')]
        [string]$Resolution = "480p"
    )

    # A dictionary to map user-friendly resolution names to their pixel dimensions (width x height).
    # This makes the code cleaner and easier to extend with new resolutions later.
    $resolutionMap = @{
        '480p'  = @{ Width = 854;  Height = 480  };
        '720p'  = @{ Width = 1280; Height = 720  };
        '1080p' = @{ Width = 1920; Height = 1080 };
        '1440p' = @{ Width = 2560; Height = 1440 };
        '4K'    = @{ Width = 3840; Height = 2160 };
    }

    # Retrieve the target dimensions from the map based on user input.
    $targetSize = $resolutionMap[$Resolution]
    Write-Verbose "Selected resolution: $($Resolution) ($($targetSize.Width)x$($targetSize.Height))"

    try {
        # Load necessary UI Automation assemblies.
        Add-Type -AssemblyName UIAutomationClient
        Add-Type -AssemblyName UIAutomationTypes

        # Get the root element of the desktop, which is the parent of all application windows.
        $rootElement = [System.Windows.Automation.AutomationElement]::RootElement
        if (-not $rootElement) {
            Write-Error "Could not get the desktop root element for UI Automation." -ErrorAction Stop
            return
        }

        # Find the first child window of the desktop that matches the provided title.
        # The Name property of an AutomationElement corresponds to the window title.
        Write-Verbose "Searching for a window with title like '$($WindowTitle)'..."
        $windowElement = $rootElement.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition) `
            | Where-Object { $_.Current.Name -like $WindowTitle } `
            | Select-Object -First 1

        if (-not $windowElement) {
            Write-Error "Could not find an open window with a title like '$($WindowTitle)'. Please ensure the window is open and the title is correct."  -ErrorAction Stop
            return
        }
        
        $foundWindowTitle = $windowElement.Current.Name
        Write-Verbose "Found window: '$($foundWindowTitle)'"

        # Get the TransformPattern for the window element. This pattern allows programmatic resizing.
        $transformPattern = $windowElement.GetCurrentPattern([System.Windows.Automation.TransformPatternIdentifiers]::Pattern)

        if (-not $transformPattern) {
            Write-Error "The found window '$($foundWindowTitle)' does not support resizing through UI Automation." -ErrorAction Stop
            return
        }
        
        if (-not $transformPattern.Current.CanResize) {
            Write-Error "The found window '$($foundWindowTitle)' reports that it cannot be resized." -ErrorAction Stop
            return
        }

        # Call the Resize method from the TransformPattern to set the new size.
        Write-Verbose "Attempting to resize window to $($targetSize.Width)x$($targetSize.Height)..."
        $transformPattern.Resize($targetSize.Width, $targetSize.Height)

        Write-Host "Successfully resized window '$($foundWindowTitle)' to $($Resolution)." -ForegroundColor Green
    }
    catch {
        # Catch any other exceptions that might occur during the process.
        Write-Error "An error occurred: $($_.Exception.Message)" -ErrorAction Stop
    }
}

