<#
.SYNOPSIS
    Parses iCalendar (.ics) files into standard, analytics-ready PowerShell custom objects.

.DESCRIPTION
    The Parse-iCal function reads raw iCalendar data (typically piped from a file), 
    reconstructs folded multi-line properties, and outputs beautifully structured 
    [PSCustomObject] items representing each VEVENT. 

    Parse-iCal reads .ics files and outputs standard PowerShell objects.
    The only additional custom field is DurationMinutes, along with derived date
    fields (Date, Year, Month, Day, Weekday, AllDay), making time analysis 
    extremely easy in Excel, Power BI, and other scripting environments.

.PARAMETER Text
    Specifies the raw string array representing the lines of the .ics file.
    This accepts pipeline input directly from commands like Get-Content.

.PARAMETER IncludeCalendarName
    If specified, appends the calendar name (from the X-WR-CALNAME field) 
    to the final output objects as the 'Calendar' property.

.PARAMETER IncludeTimeIndicators
    If specified, appends relative time boolean flags to the output:
    IsToday, IsTomorrow, IsThisWeek, and IsThisMonth.

.INPUTS
    System.String
        You can pipe the raw lines of an .ics file into this cmdlet.

.OUTPUTS
    System.Management.Automation.PSCustomObject
        Outputs objects containing Summary, Start, End, DurationMinutes, AllDay, 
        Date, Year, Month, Day, Weekday, Location, and Description.
        (Relative time flags are appended if -IncludeTimeIndicators is used).

.EXAMPLE
    Get-Content -Path "C:\temp\calendar.ics" | Parse-iCal | Format-Table -AutoSize

    Displays all events in a clean, standard console table.

.EXAMPLE
    Get-Content -Path "C:\temp\calendar.ics" | Parse-iCal | Export-Csv -Path "C:\temp\analytics.csv" -NoTypeInformation

    Parses the calendar and directly exports it to a CSV file. The included DurationMinutes 
    and date derivative columns make this CSV instantly ready for Excel or Power BI analysis.

.EXAMPLE
    Get-Content -Path "C:\temp\calendar.ics" | Parse-iCal -IncludeCalendarName | Out-GridView

    Sends all parsed events to an interactive GUI window, including the source Calendar name.

.NOTES
    Limitations & Scope:
    1. Recurring Events (RRULE): 
       This parser reads static event blocks. It does NOT expand or calculate recurring instances 
       defined by RRULE attributes. It will only return the base instance or individual customized exceptions.
    2. Time Zones (VTIMEZONE):
       Dates are parsed directly from the string representation using local system time unless they are 
       explicitly specified as UTC (suffix 'Z'). Custom timezone definitions in VTIMEZONE blocks are not resolved.
    3. Excluded Blocks:
       Non-VEVENT blocks (e.g., VTODO, VALARM, VJOURNAL) are ignored during the parsing cycle.
#>
function Parse-iCal {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [string[]]
        $Text,

        [Parameter(Mandatory = $false)]
        [switch]
        $IncludeCalendarName,

        [Parameter(Mandatory = $false)]
        [switch]
        $IncludeTimeIndicators
    )

    begin {
        Write-Verbose "Initializing Parse-iCal state engine."

        # State Tracking Variables
        $script:lineCounter         = 0
        $script:inVeventBlock       = $false
        $script:currentCalendarName = "-"
        $script:previousLine        = ""
        $script:accumulatedDesc     = ""

        # Base Dates for Relative Time Indicators (Calculated once per run)
        $script:baseNow         = Get-Date
        $script:baseToday       = $script:baseNow.Date
        $script:baseTomorrow    = $script:baseToday.AddDays(1)
        $script:baseStartOfWeek = $script:baseToday.AddDays(-[int]$script:baseToday.DayOfWeek) # Sunday as start of week
        $script:baseEndOfWeek   = $script:baseStartOfWeek.AddDays(7).AddTicks(-1)

        # Temporary storage for properties of the event currently being parsed
        $script:eventProps = @{
            Start       = $null
            End         = $null
            Summary     = ""
            Location    = ""
            Description = ""
            IsAllDay    = $false
        }

        # Regex to strip the "PROPERTY_NAME;PARAMETERS:" prefix from an iCal line
        $script:propertyPrefixRegex = "^[^:]+:"

        # Why: iCal specifications (RFC 5545) escape backslashes, commas, and semi-colons.
        # What: This helper restores the intended raw text representation.
        function Get-UnescapedText ([string]$text) {
            if ([string]::IsNullOrEmpty($text)) { return "" }
            return $text -replace '\\\\', '\' `
                        -replace '\\,', ',' `
                        -replace '\\;', ';' `
                        -replace '\\N', [Environment]::NewLine `
                        -replace '\\n', [Environment]::NewLine
        }

        # Why: To safely parse iCal's unique date formats (YYYYMMDDTHHMMSS or YYYYMMDD) to [DateTime].
        # What: Returns a hashtable with the parsed DateTime and a boolean indicating if it's an All-Day event.
        function Convert-iCalDateToDateTime ([string]$icalDate) {
            if ([string]::IsNullOrEmpty($icalDate)) { return $null }

            # Remove timezone parameter prefix if present (e.g., "TZID=America/New_York:20260626T120000")
            if ($icalDate -match ':') {
                $icalDate = $icalDate -replace '^.*:', ''
            }

            # Check for UTC designator 'Z'
            $isUtc = $icalDate.EndsWith('Z')
            $cleanDate = $icalDate -replace 'Z$', ''
            $isAllDay = $false

            try {
                if ($cleanDate -match 'T') {
                    # Format: YYYYMMDDTHHMMSS -> YYYY-MM-DD HH:MM:SS
                    $formattedString = $cleanDate -replace '^(....)(..)(..)T(..)(..)(..).*$', '$1-$2-$3 $4:$5:$6'
                } else {
                    # Format: YYYYMMDD -> YYYY-MM-DD 00:00:00 (All-day event)
                    $formattedString = $cleanDate -replace '^(....)(..)(..).*$', '$1-$2-$3 00:00:00'
                    $isAllDay = $true
                }

                [datetime]$parsedDate = Get-Date $formattedString
                if ($isUtc) {
                    $parsedDate = $parsedDate.ToLocalTime()
                }
                
                return @{
                    Date     = $parsedDate
                    IsAllDay = $isAllDay
                }
            }
            catch {
                Write-Debug "Failed to parse date string: $icalDate. Returning `$null."
                return $null
            }
        }

        # Why: To construct and yield the clean, user-friendly, analytics-ready custom object output.
        function Invoke-OutputEvent {
            if ($null -eq $script:eventProps.Start) {
                Write-Debug "Skipping event output because DTSTART is missing."
                return
            }

            # Handle missing end dates gracefully by assuming it ends at the start time
            $endDateTime = if ($null -eq $script:eventProps.End) { $script:eventProps.Start } else { $script:eventProps.End }
            $duration = $endDateTime - $script:eventProps.Start
            $durationMinutes = [Math]::Round($duration.TotalMinutes)

            $outputHash = [ordered]@{
                Summary         = Get-UnescapedText $script:eventProps.Summary
                Start           = $script:eventProps.Start
                End             = $endDateTime
                DurationMinutes = $durationMinutes
                AllDay          = $script:eventProps.IsAllDay
                Date            = $script:eventProps.Start.ToString('yyyy-MM-dd')
                Year            = $script:eventProps.Start.Year
                Month           = $script:eventProps.Start.Month
                Day             = $script:eventProps.Start.Day
                Weekday         = $script:eventProps.Start.DayOfWeek.ToString()
                Location        = Get-UnescapedText $script:eventProps.Location
                Description     = Get-UnescapedText $script:accumulatedDesc
            }

            # Optionally append relative time indicators if requested
            if ($IncludeTimeIndicators) {
                $eventDateOnly = $script:eventProps.Start.Date
                $outputHash["IsToday"]     = ($eventDateOnly -eq $script:baseToday)
                $outputHash["IsTomorrow"]  = ($eventDateOnly -eq $script:baseTomorrow)
                $outputHash["IsThisWeek"]  = ($script:eventProps.Start -ge $script:baseStartOfWeek) -and ($script:eventProps.Start -le $script:baseEndOfWeek)
                $outputHash["IsThisMonth"] = ($script:eventProps.Start.Year -eq $script:baseNow.Year) -and ($script:eventProps.Start.Month -eq $script:baseNow.Month)
            }

            # Optionally append the calendar name if requested
            if ($IncludeCalendarName) {
                $outputHash["Calendar"] = Get-UnescapedText $script:currentCalendarName
            }

            [PSCustomObject]$outputHash
        }

        # Why: Parses an established, single logical line of property and value.
        function Process-PropertyLine ([string]$line) {
            if ([string]::IsNullOrWhiteSpace($line)) { return }

            # Extract values for specific global calendar attributes
            if ($line -match '^X-WR-CALNAME:') {
                $script:currentCalendarName = ($line -replace $script:propertyPrefixRegex, '').Trim()
                if ([string]::IsNullOrEmpty($script:currentCalendarName)) {
                    $script:currentCalendarName = "-"
                }
                Write-Verbose "Detected Calendar Name: $script:currentCalendarName"
                return
            }

            # Detect the boundaries of an event block
            if ($line -match '^BEGIN:VEVENT') {
                $script:inVeventBlock       = $true
                $script:accumulatedDesc     = ""
                $script:eventProps.Start    = $null
                $script:eventProps.End      = $null
                $script:eventProps.Summary  = ""
                $script:eventProps.Location = ""
                $script:eventProps.IsAllDay = $false
                Write-Debug "Entered VEVENT block."
                return
            }

            if ($line -match '^END:VEVENT') {
                if ($script:inVeventBlock) {
                    Invoke-OutputEvent
                    $script:inVeventBlock = $false
                    Write-Debug "Exited VEVENT block and outputted object."
                }
                return
            }

            # Guard clause: only parse contents if we are physically inside a VEVENT container
            if (-not $script:inVeventBlock) { return }

            # Process standard event properties
            $value = ($line -replace $script:propertyPrefixRegex, '').Trim()

            switch -Regex ($line) {
                '^DTSTART' {
                    $parsed = Convert-iCalDateToDateTime $value
                    if ($null -ne $parsed) {
                        $script:eventProps.Start    = $parsed.Date
                        $script:eventProps.IsAllDay = $parsed.IsAllDay
                    }
                    break
                }
                '^DTEND' {
                    $parsed = Convert-iCalDateToDateTime $value
                    if ($null -ne $parsed) {
                        $script:eventProps.End = $parsed.Date
                    }
                    break
                }
                '^SUMMARY' {
                    $script:eventProps.Summary = $value
                    break
                }
                '^LOCATION' {
                    $script:eventProps.Location = $value
                    break
                }
                '^DESCRIPTION' {
                    $script:accumulatedDesc = $value
                    break
                }
                default {
                    # Why: Continuation lines (e.g., long descriptions) in RFC 5545 might fall into default parsing.
                    # What: Only append if the line does not start with a new property definition schema.
                    if ($line -notmatch '^([A-Z\-]+)(;[^:]+)?:') {
                        if (-not [string]::IsNullOrEmpty($script:accumulatedDesc)) {
                            $script:accumulatedDesc += " " + $line.Trim()
                        }
                    }
                    break
                }
            }
        }
    }

    process {
        foreach ($line in $Text) {
            $script:lineCounter++

            # Guard Clause: Handle the very first line of streaming pipeline inputs
            if ($script:lineCounter -eq 1) {
                $script:previousLine = $line
                continue
            }

            # Why: RFC 5545 defines "folding". Long lines are split; continuation lines begin with space/tab.
            # What: If the current line is folded, merge it with the previous accumulated content.
            if ($line -match '^\s+') {
                $unfoldedSegment = $line -replace '^\s+', ''
                $script:previousLine += $unfoldedSegment
            } else {
                # Since this line is NOT folded, the accumulated 'previousLine' is now guaranteed complete.
                Process-PropertyLine $script:previousLine
                $script:previousLine = $line
            }
        }
    }

    end {
        # Process the last remaining line left over in the buffer
        if (-not [string]::IsNullOrEmpty($script:previousLine)) {
            Process-PropertyLine $script:previousLine
        }
        Write-Verbose "Finished processing $script:lineCounter lines. Parse-iCal completed successfully."
    }
}
