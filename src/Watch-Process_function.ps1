<#
.SYNOPSIS
    A lightweight, top-like process monitor for PowerShell.

.DESCRIPTION
    Displays a real-time, auto-refreshing list of processes. 
    Supports sorting by CPU or Memory, highlighting specific processes, and 
    prevents screen flickering by overwriting the terminal buffer.

.PARAMETER MaxRows
    The number of process rows to display. Defaults to 20.

.PARAMETER SortBy
    The metric to sort by. Accepts 'CPU' or 'Memory'. Defaults to 'CPU'.

.PARAMETER HighlightName
    A process name (or part of it) to highlight in the list for easy tracking.

.PARAMETER RefreshInterval
    The delay between updates in seconds. Defaults to 1.

.EXAMPLE
    Watch-Process -MaxRows 15 -SortBy Memory -HighlightName "chrome"
    Displays the top 15 memory-consuming processes and highlights anything containing "chrome".

.NOTES
    - CPU values represent total processor time (seconds), not instantaneous % usage.
    - Some system processes may not yield CPU data due to permission restrictions.
    - Press Ctrl+C to exit the monitor.
#>
function Watch-Process {
    [CmdletBinding()]
    param (
        [Alias('max')]
        [int]$MaxRows = 20,
        [Alias('sort')]
        [ValidateSet("CPU", "Memory")]
        [string]$SortBy = "CPU",
        [Alias('highlight')]
        [string]$HighlightName = "",
        [Alias('interval')]
        [int]$RefreshInterval = 1
    )

    # ANSI Escape Sequences for terminal control
    $Esc = [char]27
    $CursorHome  = "$Esc[H"  # Moves cursor to 0,0
    $ClearLine   = "$Esc[K"  # Clears from cursor to end of line
    $ClearScreen = "$Esc[J"  # Clears from cursor to end of screen
    $BoldYellow  = "$Esc[1;33m"
    $ResetColor  = "$Esc[0m"

    # Sorting logic mapping
    $SortProperty = if ($SortBy -eq "Memory") { "WorkingSet64" } else { "CPU" }

    try {
        # Clear the host once at the start to prepare the canvas
        Clear-Host
        
        while ($true) {
            # 1. Fetch Terminal Metadata
            $Width = $Host.UI.RawUI.WindowSize.Width
            
            # 2. Gather and Sort Process Data
            # Note: We fetch more than needed then select to ensure sorting is accurate
            $ProcessList = Get-Process | 
                Where-Object { $_.Id -ne $PID } | # Optional: exclude this script
                Sort-Object $SortProperty -Descending | 
                Select-Object -First $MaxRows

            # 3. Build the Output Buffer
            # Using StringBuilder is more performant than string concatenation in loops
            $Buffer = New-Object System.Text.StringBuilder
            [void]$Buffer.Append($CursorHome)

            # Header Information
            $Timestamp = Get-Date -Format "HH:mm:ss"
            $StatusLine = " [WATCH-PROCESS] Time: $Timestamp | Sorting: $SortBy | Rows: $MaxRows "
            [void]$Buffer.AppendLine($StatusLine.PadRight($Width).Substring(0, $Width))
            
            $ColHeader = " {0,7} {1,10} {2,12}  {3}" -f "PID", "CPU(s)", "Mem(MB)", "ProcessName"
            [void]$Buffer.AppendLine($ColHeader.PadRight($Width).Substring(0, $Width))
            [void]$Buffer.AppendLine("-" * $Width)

            # 4. Format Each Process Row
            foreach ($Proc in $ProcessList) {
                try {
                    $MemMB = "{0:N1}" -f ($Proc.WorkingSet64 / 1MB)
                    $CpuSec = if ($Proc.CPU) { "{0:N1}" -f $Proc.CPU } else { "0.0" }
                    
                    # Construct the raw text row
                    $RawRow = " {0,7} {1,10} {2,12}  {3}" -f $Proc.Id, $CpuSec, $MemMB, $Proc.ProcessName
                    
                    # Truncate row if it exceeds terminal width to prevent wrapping
                    if ($RawRow.Length -gt $Width) {
                        $RawRow = $RawRow.Substring(0, $Width)
                    } else {
                        $RawRow = $RawRow.PadRight($Width)
                    }

                    # Apply highlighting if name matches
                    if ($HighlightName -and $Proc.ProcessName -like "*$HighlightName*") {
                        [void]$Buffer.AppendLine("$BoldYellow$RawRow$ResetColor")
                    } else {
                        [void]$Buffer.AppendLine($RawRow)
                    }
                } catch {
                    # Skip processes that are terminated during the loop or lack permissions
                    continue
                }
            }

            # Clear any leftover lines from the previous frame (e.g., if process count drops)
            [void]$Buffer.Append($ClearScreen)

            # 5. Single-pass Write to Console
            Write-Host $Buffer.ToString() -NoNewline

            Start-Sleep -Seconds $RefreshInterval
        }
    }
    catch {
        Write-Warning "Monitor stopped: $($_.Exception.Message)"
    }
}
