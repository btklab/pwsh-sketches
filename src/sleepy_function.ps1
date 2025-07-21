<#
.SYNOPSIS
    sleepy - Sleep with progress bar.

    A versatile timer and clock utility for PowerShell
    that displays a progress bar.

    This function can act as a countdown timer, a stopwatch, or a clock. 
    It's designed to be a helpful tool for managing time directly from the command line, 
    with a visual progress bar to track the passage of time. 
    By default, it functions as a 25-minute Pomodoro timer. 
    It can also be integrated with the 'teatimer' function for notifications.

    Originally inspired by mattn/sleepy: https://github.com/mattn/sleepy
    License: The MIT License (MIT): Copyright (c) 2022 Yasuhiro Matsumoto

.LINK
    Write-Progress
    https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/write-progress

.PARAMETER Minutes
    Specifies the duration of the timer in minutes.
    If no duration parameter (-Hours, -Seconds, -Until) is provided, this defaults to 25 minutes for the Pomodoro Technique.

.PARAMETER Hours
    Specifies the duration of the timer in hours.

.PARAMETER Seconds
    Specifies the duration of the timer in seconds.

.PARAMETER Until
    Specifies the exact time when the timer should end (e.g., "17:00", "22:30").
    If the specified time has already passed for the current day, it defaults to the next day.

.PARAMETER Past
    When enabled, the function will start counting up the elapsed time after the initial countdown has finished. 
    This is useful for tracking how much time has passed since a task was due.

.PARAMETER TeaTimer
    Calls the 'teatimer' function to create a notification when the timer completes.
    This requires the 'teatimer' function to be available in your environment.

.PARAMETER Infinit
    Runs as an infinite stopwatch, counting up from the moment it's started.

.PARAMETER Clock
    Runs in clock mode, displaying the current time and date.

.PARAMETER FirstBell
    Rings a preliminary bell a specified number of minutes before the timer ends.
    This also requires the 'teatimer' function.

.PARAMETER Message
    Displays start and end messages in the console.

.PARAMETER Span
    Specifies the update interval for the progress bar in seconds. Default is 1 second.

.PARAMETER CountDown
    When specified, the progress bar will decrease from 100% to 0% instead of increasing.

.EXAMPLE
    # Example 1: Start a default 25-minute Pomodoro timer.
    sleepy

.EXAMPLE
    # Example 2: Set a timer for 10 seconds.
    sleepy -s 10

.EXAMPLE
    # Example 3: Set a timer for 1.5 hours.
    sleepy -h 1.5

.EXAMPLE
    # Example 4: Set a timer that ends at 10:30 PM today.
    sleepy -to "22:30"

.EXAMPLE
    # Example 5: Count down for 5 seconds, then count up the elapsed time after it finishes.
    sleepy -s 5 -p

.EXAMPLE
    # Example 6: Use as an infinite stopwatch.
    sleepy -i

.EXAMPLE
    # Example 7: Use as a simple clock, updating every 300ms.
    sleepy -c

.EXAMPLE
    # Example 8: Set a 15-minute timer with a preliminary notification 5 minutes before the end.
    # This requires the 'teatimer' command to be available.
    sleepy -m 15 -f 5

.EXAMPLE
    # Example 9: Set a 30-second timer and trigger a 'teatimer' notification upon completion.
    sleepy -s 30 -t

.EXAMPLE
    # Example 10: Display start and end messages for a 3-second timer.
    sleepy -s 3 -Message

.EXAMPLE
    # Example 11: Specify Start and End
    sleepy -t -p -Start 09:00 -End 17:00

.EXAMPLE
    # Example 12: Set a 1-minute timer with a countdown progress bar.
    sleepy -m 1 -CountDown
#>
function sleepy {
    Param(
        [Parameter(Position=0,Mandatory=$False)]
        [Alias('m')]
        [double] $Minutes,

        [Parameter(Mandatory=$False)]
        [Alias('h')]
        [double] $Hours,

        [Parameter(Mandatory=$False)]
        [Alias('s')]
        [double] $Seconds,

        [Parameter(Mandatory=$False)]
        [Alias('To', 'End')]
        [datetime] $Until,

        [Parameter(Mandatory=$False)]
        [Alias('p')]
        [switch] $Past,

        [Parameter(Mandatory=$False)]
        [Alias('t', 'tea')]
        [switch] $TeaTimer,

        [Parameter(Mandatory=$False)]
        [Alias('i')]
        [switch] $Infinit,

        [Parameter(Mandatory=$False)]
        [Alias('c')]
        [switch] $Clock,

        [Parameter(Mandatory=$False)]
        [Alias('f')]
        [int] $FirstBell,

        [Parameter(Mandatory=$False)]
        [switch] $Message,

        [Parameter(Mandatory=$False)]
        [Alias('Begin', 'From')]
        [datetime] $Start,

        [Parameter(Mandatory=$False)]
        [Alias('d')]
        [double] $Span = 1,

        [Parameter(Mandatory=$False)]
        [Alias('cd')]
        [switch] $CountDown
    )
    # private function
    # is command exist?
    function isCommandExist ([string]$cmd) {
        try { Get-Command $cmd -ErrorAction Stop | Out-Null
            return $True
        } catch {
            return $False
        }
    }
    # convert timespan to strings
    function span2str ($timespan){
        if ($timespan.Days -ge 1){
            [string] $sStr = $timespan.ToString("dd\.hh\:mm\:ss")
        } else {
            if ($timespan.Hours -ge 1){
                [string] $sStr = $timespan.ToString("hh\:mm\:ss")
            } else {
                [string] $sStr = $timespan.ToString("mm\:ss")
            }
        }
        return $sStr
    }
    # past timer (minutes)
    $pMin = 59
    # set time span (seconds)
    if($Hours){
        [double] $addSec = $Hours * 60 * 60
        [string] $dStr = "$Hours hr"
    } elseif ($Minutes){
        [double] $addSec = $Minutes * 60
        [string] $dStr = "$Minutes min"
    } elseif ($Seconds){
        [double] $addSec = $Seconds
        [string] $dStr = "$Seconds sec"
    } else {
        # pomodoro: 25 min
        [double] $addSec = 25 * 60
        [string] $dStr = "25 min"
    }
    # Record the current time as the start of the interval
    if ( $Start ){
        [datetime] $sDateTime = $Start
    } else {
        [datetime] $sDateTime = Get-Date
    }
    # Determine the end time based on the optional $Until parameter
    if ( $Until ){
        # If $Until is in the future, use it directly
        if ( $Until -ge $sDateTime ){
            [datetime] $eDateTime = $Until
        } else {
            # If $Until has already passed today, assume it refers to the next day
            [datetime] $eDateTime = $Until.AddDays(1)
        }    
        # Calculate the timespan between start and end
        [timespan] $untilTimeSpan = New-TimeSpan -Start $sDateTime -End $eDateTime
        # Total seconds from now until the adjusted $Until
        [double] $addSec = $untilTimeSpan.TotalSeconds
        # Format the timespan into a display string (e.g., "1h 30m")
        [string] $dStr = span2str $untilTimeSpan
    }
    else {
        # If $Until is not specified, use the existing $addSec value to compute end time
        [datetime] $eDateTime = $sDateTime.AddSeconds($addSec)
    }
    # Final timespan object representing the entire interval
    $eSpan = New-TimeSpan -Start $sDateTime -End $eDateTime
    # now time
    [datetime] $nDateTime = Get-Date
    # duration
    [double] $sSec = $sDateTime.Minute
    [double] $eSec = $eDateTime.Minute
    # infinit
    if ($Infinit){
        while ($True){
            [datetime] $nDateTime = Get-Date
            $iSpan = New-TimeSpan -Start $sDateTime -End $nDateTime
            [string] $iStr = span2str $iSpan
            [string] $nStr = (Get-Date).ToString('M/d (ddd) HH:mm:ss')
            $splatting = @{
                Activity = "$iStr"
                Status = " $nStr"
                PercentComplete = 1
                Id = 1
            }
            Write-Progress @splatting
            Start-Sleep -Milliseconds 200
        }
        return
    }
    if ($Clock){
        while ($True){
            [datetime] $nDateTime = Get-Date
            $iSpan = New-TimeSpan -Start $sDateTime -End $nDateTime
            [string] $iStr = (Get-Date).ToString('HH:mm')
            [string] $nStr = (Get-Date).ToString('M/d (ddd)')
            $splatting = @{
                Activity = "$iStr"
                Status = " $nStr"
                PercentComplete = 1
                Id = 1
            }
            Write-Progress @splatting
            Start-Sleep -Milliseconds 300
        }
        return
    }
    # main loop
    if ($Message){
        Write-Host "st: $((Get-Date).ToString('M/d HH:mm:ss')) ($($dStr))" -ForegroundColor Green
    }
    if ($FirstBell){
        if (-not (isCommandExist "teatimer")){
            Write-Error "command: ""teatimer"" is not available." -ErrorAction Stop
        }
        [int] $fBell = -1 * $FirstBell
        teatimer -Text "last $FirstBell minutes" -Title "First bell" -At $eDateTime.AddMinutes($fBell).ToString('yyyy-MM-dd HH:mm:ss') -Quiet
    }
    while ($nDateTime -le $eDateTime) {
        [datetime] $nDateTime = Get-Date
        $tSpan = New-TimeSpan -Start $sDateTime -End $nDateTime
        $rSpan = New-TimeSpan -Start $nDateTime -End $eDateTime
        [int] $tSec = $tSpan.TotalSeconds
        [int] $dSec = $rSpan.TotalSeconds
        
        if ($CountDown) {
            # Countdown logic: percentage based on remaining time
            [double] $perc_double = $dSec / $addSec * 100
            if ($perc_double -lt 0) { $perc_double = 0 }
            [int] $perc = [int]$perc_double
            
            # Use Ceiling to avoid showing 1 second less due to timing and rounding.
            # Calculate the remaining seconds and round up to the nearest integer.
            $displaySeconds = [Math]::Ceiling($rSpan.TotalSeconds)
            if ($displaySeconds -lt 0) { $displaySeconds = 0 }
            # Create a new TimeSpan object from the calculated seconds for display.
            $displayTimeSpan = [TimeSpan]::FromSeconds($displaySeconds)
            
            [string] $rStr = span2str $displayTimeSpan
            [string] $eStr = span2str $eSpan
            $activityText = "$($rStr) of $($eStr)"
        } else {
            # Original count-up logic: percentage based on elapsed time
            [double] $perc_double = $tSec / $addSec * 100
            if ($perc_double -gt 100) { $perc_double = 100 }
            if ($perc_double -le 0.5) { $perc = 1 } else { $perc = [int]$perc_double }
            
            [string] $eStr = span2str $eSpan
            [string] $tStr = span2str $tSpan
            $activityText = "$($tStr) / $($eStr)"
        }

        $splatting = @{
            Activity = $activityText
            Status = "Progress: $perc%"
            PercentComplete = $perc
            SecondsRemaining = $dSec
            Id = 1
        }
        Write-Progress @splatting
        Start-Sleep -Seconds $Span
    }
    if ($Message){
        Write-Host "en: $((Get-Date).ToString('M/d HH:mm:ss'))" -ForegroundColor Green
    }
    if ($TeaTimer){
        if (-not (isCommandExist "teatimer")){
            Write-Error "command: ""teatimer"" is not available." -ErrorAction Stop
        }
        #teatimer -At (Get-Date).AddSeconds(2).ToString('yyyy-MM-dd HH:mm:ss') -Quiet
        teatimer -Quiet
    }

    # past timer
    if ($Past){
        [datetime] $sDateTime = $eDateTime
        while ($True){
            [datetime] $nDateTime = Get-Date
            $iSpan = New-TimeSpan -Start $sDateTime -End $nDateTime
            [string] $iStr = span2str $iSpan
            [string] $iStr = "past: $iStr"
            [string] $nStr = (Get-Date).ToString('M/d (ddd) HH:mm')
            $splatting = @{
                Activity = "$iStr"
                Status = " $nStr"
                PercentComplete = 1
                ParentId = 1
            }
            Write-Progress @splatting
            Start-Sleep -Milliseconds 300
        }
    }
}

