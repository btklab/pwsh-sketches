<#
.SYNOPSIS
    Get-Gcalendar (Alias:gcalendar) - Connects to Google Calendar and retrieves a list of events.

    Connects to the Google Calendar API using OAuth 2.0 and retrieves a list of events from the user's account.

    Google Calendar API Setup Instructions:

    1. Go to Google Cloud Console https://console.cloud.google.com/
    2. Create a new project or select an existing one.
    3. Enable Google Calendar API: APIs & Services > Library > Search "Google Calendar API" > Enable.
    4. Navigate to APIs & Services > OAuth consent screen.
        - Fill in the required fields (App name, User support email, etc.).
        - UserType: External, User Data
    5. Set Scope: Data Access > Create Scope > Check "https://www.googleapis.com/auth/calendar.readonly".
    6. Create credentials: APIs & Services > Credentials > Create Credentials > OAuth 2.0 Client IDs.
        - Application type: Desktop app.
    7. Download the JSON credentials file.
        - Place the credentials file in the same directory as this script.
        - Rename it to 'gcalendar-credentials.json'.
    8. Add test users: APIs & Services > OAuth consent screen > Test users.
        - Add your Google account email to the list of test users.
    9. AccessToken handling Tips
        - https://developers.google.com/identity/protocols/oauth2/web-server#offline

.DESCRIPTION
    The Get-Gcalendar function handles the OAuth 2.0 authentication process with the Google API to access Google Calendar.
    On the first run, it prompts the user to authenticate via a web browser and saves a refresh token to a file.
    Subsequent runs use the saved token to get a new access token without user interaction.

    This function retrieves events from the specified Google Calendar. By default, it fetches events from the primary calendar.

.LINK
    Set-DotEnv, Get-Gmail, Get-Gcalendar

.PARAMETER CalendarId
    The ID of the calendar to retrieve events from. Defaults to 'primary'.

.PARAMETER MaxResults
    The maximum number of events to retrieve. Default is 10.

.PARAMETER TimeMin
    The start date/time for filtering events (inclusive). Defaults to the current date.

.PARAMETER TimeMax
    The end date/time for filtering events (exclusive). Defaults to 7 days from the current date.

.PARAMETER CredentialJsonPath
    Path to the 'calendar-credentials.json' file. Defaults to the script's directory.

.PARAMETER TokenFilePath
    Path to save/load the 'calendar-refresh-token.json' file. Defaults to the script's directory.

.PARAMETER EnvNameCredentialJson
    Environment variable name for calendar credentials JSON.

.PARAMETER EnvNameToken
    Environment variable name for calendar refresh token.

.PARAMETER EnvFilePath
    Path to the .myenv or .myenv.gpg file for environment variables.

.EXAMPLE
    Get-Gcalendar -MaxResults 5
    # Retrieves the next 5 events from your primary calendar.

.EXAMPLE
    Get-Gcalendar -CalendarId "your_calendar_id@group.calendar.google.com" -TimeMin (Get-Date).AddDays(-30)
    # Retrieves events from a specific calendar starting 30 days ago.

.OUTPUTS
    An array of PSCustomObject, each representing a Google Calendar event.

.NOTES
    Author: Gemini
    Date: 2025-07-12
    Requires PowerShell 5.1 or later.
#>
function Get-Gcalendar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$CalendarId = "primary",

        [Parameter(Mandatory = $false)]
        [Alias('max','m')]
        [int]$MaxResults = 100,

        [Parameter(Mandatory = $false)]
        [Alias('start', 's')]
        [string]$TimeMin,

        [Parameter(Mandatory = $false)]
        [Alias('end', 'e')]
        [string]$TimeMax,

        [Parameter(Mandatory = $false)]
        [Alias('cred', 'credentials')]
        [string]$CredentialJsonPath = "./gcalendar-credentials.json",

        [Parameter(Mandatory = $false)]
        [Alias('token', 'refreshToken')]
        [string]$TokenFilePath = "./gcalendar-refresh-token.json",

        [Parameter(Mandatory = $false)]
        [Alias('envCred', 'envCredentials')]
        [string]$EnvNameCredentialJson = "GCALENDAR_CREDENTIALS",

        [Parameter(Mandatory = $false)]
        [Alias('envToken', 'envRefreshToken')]
        [string]$EnvNameToken = "GCALENDAR_REFRESH_TOKEN",

        [Parameter(Mandatory = $false)]
        [string]$EnvFilePath = "./.myenv",

        [Parameter(Mandatory = $false)]
        [string]$TimeZone = "Asia/Tokyo",

        [Parameter(Mandatory = $false)]
        [string]$TimeFix = "+09:00",

        [Parameter(Mandatory = $false)]
        [switch]$Todo,
        
        [Parameter(Mandatory = $false)]
        [switch]$Ticket,
        
        [Parameter(Mandatory = $false)]
        [Alias('a')]
        [int[]] $AddDays = @(-1,7),
        
        [Parameter(Mandatory = $false)]
        [string]$Subject,

        [Parameter(Mandatory = $false)]
        [Alias('now', 'n')]
        [switch]$NowTime,

        [Parameter(Mandatory = $false)]
        [Alias('d')]
        [switch]$Detail,

        [Parameter(Mandatory = $false)]
        [switch]$iCal
    )
    [bool] $isTimeMinSpecified = $false
    [bool] $isTimeMaxSpecified = $false
    [bool] $isAddDaysSpecified = $false
    if ( $NowTime ){
        [string] $zeroTime = 'HH:mm:ss'
    } else {
        [string] $zeroTime = '00:00:00'
    }
    if ( $TimeMin ){
        [bool] $isTimeMinSpecified = $true
        if ( ( Get-Date $(Get-Date $TimeMin).ToString('yyyy-MM-dd HH:mm:ss') ) -gt `
             ( Get-Date $(Get-Date $TimeMin).ToString('yyyy-MM-dd 00:00:00') ) ){
            [string] $TimeMin = (Get-Date $TimeMin).ToString("yyyy-MM-ddTHH:mm:ss")
        } else {
            [string] $TimeMin = (Get-Date $TimeMin).ToString("yyyy-MM-ddT00:00:00")        
        }
        #[string] $TimeMin = (Get-Date $TimeMin).ToUniversalTime().ToString("yyyy-MM-ddT${zeroTime}")
        [string] $TimeMin += $TimeFix
    } elseif ( $AddDays.Count -gt 1 ){
        [bool] $isAddDaysSpecified = $true
        [string] $TimeMin = (Get-Date).AddDays($AddDays[0]).ToString("yyyy-MM-ddT00:00:00")        
        [string] $TimeMin += $TimeFix
    } else {
        #[string] $TimeMin = (Get-Date).AddDays(0).ToUniversalTime().ToString("yyyy-MM-ddT${zeroTime}")
        [string] $TimeMin = (Get-Date).ToString("yyyy-MM-ddT${zeroTime}")
        [string] $TimeMin += $TimeFix
    }
    Write-Verbose "TimeMin: $TimeMin"
    if ( $TimeMax ){
        if ( ( Get-Date $(Get-Date $TimeMax).ToString('yyyy-MM-dd HH:mm:ss') ) -lt `
             ( Get-Date $(Get-Date $TimeMin).ToString('yyyy-MM-dd 23:59:59') ) ){
                [string] $TimeMax = (Get-Date $TimeMax).ToString("yyyy-MM-ddTHH:mm:ss")
        } else {
                [string] $TimeMax = (Get-Date $TimeMax).ToString("yyyy-MM-ddT23:59:59")
        }
        [bool] $isTimeMaxSpecified = $true
        #[string] $TimeMax = (Get-Date $TimeMax).ToUniversalTime().ToString("yyyy-MM-ddT23:59:59")
        [string] $TimeMax += $TimeFix
    } elseif ( $AddDays.Count -gt 0 ){
        [bool] $isAddDaysSpecified = $true
        #[string] $TimeMax = (Get-Date $TimeMin).AddDays($AddDays).ToUniversalTime().ToString("yyyy-MM-ddT23:59:59")
        if ( $AddDays.Count -eq 1){
            [string] $TimeMax = (Get-Date).AddDays($AddDays[0]).ToString("yyyy-MM-ddT23:59:59")
        } else {
            [string] $TimeMax = (Get-Date).AddDays($AddDays[1]).ToString("yyyy-MM-ddT23:59:59")
        }
        [string] $TimeMax += $TimeFix
    } else {
        #[string] $TimeMax = (Get-Date $TimeMin).AddDays(7).ToUniversalTime().ToString("yyyy-MM-ddT23:59:59")
        [string] $TimeMax = (Get-Date $TimeMin).AddDays(7).ToString("yyyy-MM-ddT23:59:59")
        [string] $TimeMax += $TimeFix
    }
    Write-Verbose "TimeMax: $TimeMax"
    if ( $Todo -or $Ticket ) {
        [string] $Subject = '^\+|^\([A-Z]\) |^\['
    }

    #region Helper Functions
    # Helper function to convert a secure string to a plain text string.
    function ConvertTo-PlainText {
        param([System.Security.SecureString]$SecureString)
        $p = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        try {
            return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($p)
        }
        finally {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($p)
        }
    }
    # is command exist?
    function isCommandExist ([string]$cmd) {
        try { Get-Command -Name $cmd -ErrorAction Stop > $Null
            return $True
        } catch {
            return $False
        }
    }
    # Escapes special characters for iCal properties.
    function Escape-iCalValue {
        param([string]$Value)
        # Replace backslashes first to avoid double escaping
        $Value = $Value -replace '\\', '\\\\'
        # Escape semicolons
        $Value = $Value -replace ';', '\;'
        # Escape commas
        $Value = $Value -replace ',', '\,'
        # Replace newlines with escaped newlines for iCal
        $Value = $Value -replace "`n", '\n'
        $Value = $Value -replace "`r", '' # Remove carriage returns
        return $Value
    }

    # Formats a DateTime object to iCal format (YYYYMMDDTHHMMSSZ or YYYYMMDD for all-day).
    function Format-iCalDateTime {
        param(
            [Parameter(Mandatory=$true)]
            [object]$DateTimeObject, # Can be string (date) or DateTime (dateTime)
            [Parameter(Mandatory=$false)]
            [switch]$IsAllDay
        )
        if ($IsAllDay) {
            # For all-day events, Google API provides 'date' like "YYYY-MM-DD"
            # iCal format for all-day is YYYYMMDD
            return ($DateTimeObject -replace '-', '')
        } else {
            # For specific time events, Google API provides 'dateTime' like "YYYY-MM-DDTHH:mm:ssZ" or with offset
            # Convert to UTC and format as YYYYMMDDTHHMMSSZ
            # Ensure it's a DateTime object first if it's a string with offset
            if ($DateTimeObject -is [string]) {
                #$dt = [datetime]::Parse($DateTimeObject).ToUniversalTime()
                $dt = [datetime]::Parse($DateTimeObject)
            } else {
                #$dt = $DateTimeObject.ToUniversalTime()
                $dt = $DateTimeObject
            }
            return $($dt.ToString("yyyyMMddTHHmmss") + $TimeFix.Replace(':', ''))
        }
    }
    #endregion

    # --- Step 1: Load Client Credentials ---
    # Check if .myenv or .myenv.gpg file exists,
    # and if so, overwrite CredentialJsonPath and TokenFilePath
    if (Test-Path -Path "$EnvFilePath.gpg") {
        [string] $myenvPath = "$EnvFilePath.gpg"
    } else {
        [string] $myenvPath = "$EnvFilePath"
    }
    if (Test-Path -LiteralPath "$myenvPath") {
        Write-Verbose "Found .myenv file. Attempting to load credentials from it."
        if ( -not (isCommandExist "Set-DotEnv") ){
            Write-Verbose "Command: 'Set-DotEnv' is not loaded. execute following dot-sourcing:"
            [string]$setDotEnvPath = Join-Path $PSScriptRoot "Set-DotEnv_function.ps1"
            [string]$setDotEnvPath = (Resolve-Path -LiteralPath "$setDotEnvPath" -Relative).Replace('\', '/')
            Write-Error ". $setDotEnvPath" -ErrorAction Stop
        }
        [string]$myenvPath = (Resolve-Path -LiteralPath "$myenvPath" -Relative).Replace('\', '/')
        Write-Verbose "Execute: Set-DotEnv command."
        Set-DotEnv -Overwrite -Execute -Quiet -Path $myenvPath
    } else {
        Write-Verbose "Do not found ""$myenvPath"" file. Attempting to load credentials from ""Env:"""
    }

    $CredentialJson = Get-ChildItem -LiteralPath "Env:" `
        | Where-Object name -eq "$EnvNameCredentialJson" `
        | Select-Object -ExpandProperty Value
    $RefreshToken = Get-ChildItem -LiteralPath "Env:" `
        | Where-Object name -eq "$EnvNameToken" `
        | Select-Object -ExpandProperty Value

    if ( $CredentialJson ){
        Write-Verbose "Loading client credentials from ""ls Env:\$EnvNameCredentialJson""."
        $clientSecrets = $CredentialJson | ConvertFrom-Json
    }
    if ( -not $clientSecrets ){
        Write-Verbose "Do not found ""ls Env:\$EnvNameCredentialJson"""
        if ( -not (Test-Path -Path $CredentialJsonPath)) {
            Write-Error "Credential file not found at ""$CredentialJsonPath"". Please follow the setup instructions." -ErrorAction Continue
        }
        Write-Verbose "Loading client credentials from ""$CredentialJsonPath""."
        $clientSecrets = Get-Content -Raw -LiteralPath $CredentialJsonPath | ConvertFrom-Json
    }
    [string]$clientId     = $clientSecrets.installed.client_id
    [string]$clientSecret = $clientSecrets.installed.client_secret
    [string]$redirectUri  = $clientSecrets.installed.redirect_uris[0]
    [string]$tokenUri     = $clientSecrets.installed.token_uri
    [string]$authUri      = $clientSecrets.installed.auth_uri

    # --- Step 2: Obtain an Access Token ---
    # Try to get a token using a saved refresh token (from environment variable or file).
    $accessToken = $null
    $refreshTokenData = $null
    if ( $RefreshToken ){
        Write-Verbose "Loading refresh token from ""ls Env:\$EnvNameToken""."
        $refreshTokenData = $RefreshToken | ConvertTo-SecureString
    } else {
        Write-Verbose "Do not found ""ls Env:\$EnvNameToken"""
        if ( -not (Test-Path -LiteralPath $TokenFilePath) ) {
            Write-Error "Refresh token file not found at ""$TokenFilePath"". Please follow the setup instructions." -ErrorAction Continue
        }
        Write-Verbose "Loading refresh token from ""file: $TokenFilePath"""
        $refreshTokenData = Get-Content -LiteralPath "$TokenFilePath" -Encoding utf8 | ConvertTo-SecureString
    }
    Write-Verbose "Refresh token found. Attempting to get a new access token."
    try {
        $refreshToken = ConvertTo-PlainText -SecureString $refreshTokenData
        $tokenRequestBody = @{
            client_id     = $clientId
            client_secret = $clientSecret
            refresh_token = $refreshToken
            grant_type    = 'refresh_token'
        }
        $tokenResponse = Invoke-RestMethod -Uri $tokenUri -Method Post -Body $tokenRequestBody
        $accessToken = $tokenResponse.access_token
        Write-Verbose "Successfully obtained a new access token."
    }
    catch {
        Write-Warning "Could not refresh the access token. Starting full authentication."
        if (Test-Path -LiteralPath $TokenFilePath) {
            Remove-Item -LiteralPath $TokenFilePath -Confirm:$false -ErrorAction SilentlyContinue
        }
    }

    # If no access token, perform the full OAuth 2.0 flow.
    if (-not $accessToken) {
        Write-Host "Starting first-time authentication. A browser window will open."
        Write-Host "Please log in and grant permission to the application."

        $scope = "https://www.googleapis.com/auth/calendar.readonly"
        $authUrl = "$authUri`?scope=$scope&redirect_uri=$redirectUri&response_type=code&client_id=$clientId&access_type=offline&prompt=consent"

        try {
            Start-Process $authUrl
        }
        catch {
            Write-Warning "Could not open the browser. Please copy and paste this URL:"
            Write-Host $authUrl
        }

        $authCode = Read-Host -Prompt "After granting permission, copy the 'code' from the URL and paste it here"

        $tokenRequestBody = @{
            code          = $authCode
            client_id     = $clientId
            client_secret = $clientSecret
            redirect_uri  = $redirectUri
            grant_type    = 'authorization_code'
        }
        $tokenResponse = Invoke-RestMethod -Uri $tokenUri -Method Post -Body $tokenRequestBody
        $accessToken  = $tokenResponse.access_token
        $refreshToken = $tokenResponse.refresh_token

        if ($refreshToken) {
            Write-Verbose "Saving new refresh token to '$TokenFilePath'."
            $refreshToken `
                | ConvertTo-SecureString -AsPlainText -Force `
                | ConvertFrom-SecureString `
                | Set-Content -Path $TokenFilePath -Encoding utf8
        }
    }

    # --- Step 3: Call the Google Calendar API ---
    if (-not $accessToken) {
        throw "Failed to obtain an access token. Cannot proceed."
    }
    
    $calendarApiUrl = "https://www.googleapis.com/calendar/v3/calendars/$($CalendarId)/events"
    $queryParams = @{
        maxResults = $MaxResults
        timeMin    = $TimeMin
        timeMax    = $TimeMax
        orderBy    = "startTime"
        singleEvents = $true # Expand recurring events into individual instances
    }

    $uriBuilder = New-Object System.UriBuilder($calendarApiUrl)
    $query = [System.Web.HttpUtility]::ParseQueryString($uriBuilder.Query)
    foreach ($key in $queryParams.Keys) {
        $query[$key] = $queryParams[$key]
    }
    $uriBuilder.Query = $query.ToString()
    $finalApiUrl = $uriBuilder.ToString()

    $headers = @{ "Authorization" = "Bearer $accessToken" }

    try {
        Write-Verbose "Fetching events from: $finalApiUrl"
        $response = Invoke-RestMethod -Uri $finalApiUrl -Headers $headers -Method Get

        if (-not $response.items) {
            #Write-Host "No events found matching your criteria."
            return
        }

        [object[]] $events = @()
        [string[]] $iCalEvents = @()
        [bool] $isEndOfPast = $false
        [datetime] $nowDateTime = Get-Date

        #$dtStamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ") # Current time for DTSTAMP
        $dtStamp = (Get-Date).ToString("yyyyMMddTHHmmss$TimeFix") # Current time for DTSTAMP

        foreach ($event in $response.items) {
            # Determine if it's an all-day event
            [bool] $isAllDay  = $false
            $startTime = $null
            $endTime   = $null
            
            if ( $Todo -and $event.summary -notmatch $Subject ){
                continue
            }
            if ( $Ticket -and $event.summary -notmatch $Subject ){
                continue
            }
        
            if ($event.start.date) {
                [bool] $isAllDay = $true
                $startTime = $event.start.date
                $endTime = $event.end.date
            } elseif ($event.start.dateTime) {
                $startTime = $event.start.dateTime
                $endTime = $event.end.dateTime
            }
            [string] $startTimeStr = if ($isAllDay) {
                $startTime + "T00:00:00" + $TimeFix
            } else {
                $($startTime -replace 'T(\d{2}:\d{2}:\d{2}).*', ' $1') + $TimeFix
            }
            [string] $endTimeStr   = if ($isAllDay) {
                $endTime + "T23:59:59" + $TimeFix
            } else {
                $($endTime -replace 'T(\d{2}:\d{2}:\d{2}).*', ' $1') + $TimeFix
            }
            [datetime] $baseDateTime = Get-Date $((Get-Date).ToString('yyyy-MM-dd 12:00:00') )
            #Write-Verbose "NowTime: $baseDateTime"
            [datetime] $startDateTime = (Get-Date $StartTimeStr)
            [datetime] $endDateTime   = (Get-Date $EndTimeStr)
            [timespan] $deltaTimeSpan = New-TimeSpan -Start $nowDateTime -End $startDateTime
            if ( [int]($deltaTimeSpan.TotalMinutes) -lt -1480 ){
                [timespan] $tmpTimeSpan = New-TimeSpan -Start $baseDateTime -End $startDateTime
                #[string] $timeDelta = '[-]'
                [string] $timeDelta = "$(($tmpTimeSpan.TotalDays).ToString('0')) d"
            } elseif ( [int]($deltaTimeSpan.TotalMinutes) -gt 1480 ){
                [timespan] $tmpTimeSpan = New-TimeSpan -Start $baseDateTime -End $startDateTime
                #[string] $timeDelta = "[+]"
                [string] $timeDelta = "+$(($tmpTimeSpan.TotalDays).ToString('0')) d"
            } else {
                [string] $timeDelta = "[$(($deltaTimeSpan.TotalHours).ToString('0')):$([math]::Abs(($deltaTimeSpan.TotalMinutes % 60)).ToString('00'))]"
                #[string] $timeDelta = "$(($tmpTimeSpan.TotalMinutes)) m"
            }

            if ( $event.recurringEventId ){
                [bool] $recurseFlag = $true
            } else {
                [bool] $recurseFlag = $false
            }
            if ( $event.birthdayProperties.Count -gt 0 ){
                [bool] $birthdayFlag = $true
            } else {
                [bool] $birthdayFlag = $false
            }

            # Construct the event object for standard 
            if ( -not $iCal ){
                if ( -not $isEndOfPast -and ($startDateTime -ge $nowDateTime) ){
                    [bool] $isEndOfPast = $true
                    $eventObject = [ordered]@{
                        #Id          = $event.id
                        Start       = $nowDateTime
                        Week        = (Get-Date $nowDateTime).ToString('(ddd)')
                        Delta       = '+---'
                        Subject     = '+---'
                    }
                    if ( $Detail ){
                        $eventObject.Location    = $null
                        $eventObject.Recurse     = $false
                        $eventObject.Color       = $null
                        $eventObject.Birthday    = $null
                        $eventObject.Creator     = $null
                        $eventObject.Status      = $null
                        $eventObject.End         = $nowDateTime
                        $eventObject.Created     = $nowDateTime
                        $eventObject.Updated     = $nowDateTime
                        $eventObject.Organizer   = $null
                        $eventObject.HtmlLink    = $null
                        $eventObject.Description = $null
                    }
                    $events += [PSCustomObject]$eventObject
                }
                $eventObject = [ordered]@{
                    #Id          = $event.id
                    Start       = $startDateTime
                    Week        = (Get-Date $StartTimeStr).ToString('(ddd)')
                    Delta       = $timeDelta
                    Subject     = $event.summary
                }
                if ( $Detail ){
                    $eventObject.Location    = $event.location
                    $eventObject.Recurse     = $recurseFlag
                    $eventObject.Color       = $event.colorId
                    $eventObject.Birthday    = $birthdayFlag
                    $eventObject.Creator     = $event.creator.email
                    $eventObject.Status      = $event.status
                    $eventObject.End         = $endDateTime
                    $eventObject.Created     = (Get-Date $event.created)
                    $eventObject.Updated     = (Get-Date $event.updated)
                    $eventObject.Organizer   = $event.organizer.email
                    $eventObject.HtmlLink    = $event.htmlLink
                    $eventObject.Description = $event.description
                }
                $events += [PSCustomObject]$eventObject
            }
            # Construct iCal event if -iCal switch is present
            if ($iCal) {
                # Determine if it's an all-day event for iCal formatting
                $iCalValueType = if ($isAllDay) { ";VALUE=DATE" } else { "" }

                # Format start and end times for iCal
                #$formattedStartTime = Format-iCalDateTime -DateTimeObject $startTime -IsAllDay:$isAllDay
                #$formattedEndTime = Format-iCalDateTime -DateTimeObject $endTime -IsAllDay:$isAllDay
                $formattedStartTime = (Get-Date $startTime).ToString('yyyy-MM-ddTHH:mm:ss') + $TimeFix
                $formattedEndTime = (Get-Date $endTime).ToString('yyyy-MM-ddTHH:mm:ss') + $TimeFix
                $summaryStr = Escape-iCalValue $($event.summary)
                [string[]] $iCalEventAry = @()
                [string[]] $iCalEventAry += "BEGIN:VEVENT"
                [string[]] $iCalEventAry += "UID:$($event.id)@google.com"
                [string[]] $iCalEventAry += "DTSTAMP:$dtStamp"
                [string[]] $iCalEventAry += "DTSTART${iCalValueType}:${formattedStartTime}"
                [string[]] $iCalEventAry += "DTEND${iCalValueType}:${formattedEndTime}"
                [string[]] $iCalEventAry += "SUMMARY:${summaryStr}"
                if ($event.description) {
                    $iCalEventAry += "DESCRIPTION:$(Escape-iCalValue $event.description)"
                }
                if ($event.location) {
                    $iCalEventAry += "LOCATION:$(Escape-iCalValue $event.location)"
                }
                if ($event.created) {
                    $iCalEventAry += "CREATED:$(Format-iCalDateTime -DateTimeObject $event.created)"
                }
                if ($event.updated) {
                    $iCalEventAry += "LAST-MODIFIED:$(Format-iCalDateTime -DateTimeObject $event.updated)"
                }
                if ($event.status) {
                    $iCalEventAry += "STATUS:$($event.status.ToUpper())"
                }
                if ($event.htmlLink) {
                    $iCalEventAry += "URL:$(Escape-iCalValue $event.htmlLink)"
                }
                $iCalEventAry += "END:VEVENT"
                $iCalEvents += $iCalEventAry
            }
        }

        if ( -not $iCal -and -not $isEndOfPast ){
            [bool] $isEndOfPast = $true
            $eventObject = [ordered]@{
                #Id          = $event.id
                Start       = $nowDateTime
                Week        = (Get-Date $nowDateTime).ToString('(ddd)')
                Delta       = '---'
                Subject     = '+now [---]'
            }
            if ( $Detail ){
                $eventObject.Location    = $null
                $eventObject.Recurse     = $false
                $eventObject.Color       = $null
                $eventObject.Birthday    = $null
                $eventObject.Creator     = $null
                $eventObject.Status      = $null
                $eventObject.End         = $nowDateTime
                $eventObject.Created     = $nowDateTime
                $eventObject.Updated     = $nowDateTime
                $eventObject.Organizer   = $null
                $eventObject.HtmlLink    = $null
                $eventObject.Description = $null
            }
            $events += [PSCustomObject]$eventObject
        }

        if ($iCal) {
            [string[]]$iCalHeaderAry = @()
            [string[]]$iCalHeaderAry += "BEGIN:VCALENDAR"
            [string[]]$iCalHeaderAry += "VERSION:2.0"
            #[string[]]$iCalHeaderAry += "PRODID:-//Google Inc//Google Calendar 70.6265//EN"
            #[string[]]$iCalHeaderAry += "CALSCALE:GREGORIAN"
            [string[]]$iCalHeaderAry += "BEGIN:VTIMEZONE"
            [string[]]$iCalHeaderAry += "TZID:$TimeZone"
            [string[]]$iCalHeaderAry += "END:VTIMEZONE"

            [string[]]$iCalFooterAry = @()
            [string[]]$iCalFooterAry += "END:VCALENDAR"

            Write-Output $iCalHeaderAry
            Write-Output $iCalEvents
            Write-Output $iCalFooterAry
            return
        } else {
            return $events
        }
    }
    catch {
        # Initialize errorBody with a generic message from the exception
        [string]$errorBody = "An unexpected error occurred: $($_.Exception.Message)"

        # If an HTTP response object is available, extract status and potentially content
        if ($null -ne $_.Exception.Response) {
            [string]$statusCode = $_.Exception.Response.StatusCode
            [string]$reasonPhrase = $_.Exception.Response.ReasonPhrase
            $errorBody = "HTTP Status: $statusCode $reasonPhrase. " # Start with status

            # Attempt to read the response content if available
            if ($null -ne $_.Exception.Response.Content) {
                try {
                    # This method is suitable for System.Net.Http.HttpResponseMessage (PowerShell Core).
                    $responseContent = $_.Exception.Response.Content.ReadAsStringAsync().Result
                    $errorBody += "Response Content: $responseContent"
                }
                catch [System.ObjectDisposedException] {
                    # Catch this specific error when the content stream has already been consumed or closed
                    $errorBody += "Error content already consumed or disposed."
                }
                catch {
                    # Catch any other errors that occur during the attempt to read response content
                    $errorBody += "Failed to read response content: $($_.Exception.Message)"
                }
            } else {
                $errorBody += "No response content available."
            }
        }
        # Fallback to ErrorDetails if it provides more specific info and wasn't covered by Response
        # This is useful for errors where $_.Exception.Response might be null but PowerShell's internal
        # error handling provides a parsed message.
        elseif ($null -ne $_.ErrorDetails -and $null -ne $_.ErrorDetails.Message) {
            $errorBody = $_.ErrorDetails.Message
        }

        # Output the final error message
        Write-Error "An error occurred while calling the Google Calendar API: $errorBody" -ErrorAction Stop
    }
}

# set alias
# This block automatically sets an alias for the function upon script load.
[String] $tmpAliasName = "gcalendar"
[String] $tmpCmdName = "Get-Gcalendar"

# Get the script's own path to inform the user if an alias conflict occurs.
[String] $tmpCmdPath = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath $($MyInvocation.MyCommand.Name) `
    | Resolve-Path -Relative

# Convert script path to Unix-style for display clarity if on Windows.
if ( $IsWindows ){ $tmpCmdPath = $tmpCmdPath.Replace('\' ,'/') }

# Check if an alias with the desired name already exists.
if ((Get-Command -Name $tmpAliasName -ErrorAction SilentlyContinue).Count -gt 0){
    try {
        # If the existing command is an alias and refers to this function, just re-set it.
        if ( (Get-Command -Name $tmpAliasName).CommandType -eq "Alias" ){
            if ( (Get-Command -Name $tmpAliasName).ReferencedCommand.Name -eq $tmpCmdName ){
                Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
                    | ForEach-Object{
                        Write-Host "$($_.DisplayName) (updated)" -ForegroundColor Green # Indicate alias was updated
                    }
            } else {
                # Alias exists but points to a different command; throw error.
                throw
            }
        # If the existing command is an executable (e.g., gitbash.exe), allow overriding with this alias.
        } elseif ( "$((Get-Command -Name $tmpAliasName).Name)" -match '\.exe$') {
            Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
                | ForEach-Object{
                    Write-Host "$($_.DisplayName) (overriding existing executable)" -ForegroundColor Yellow # Indicate override
                }
        } else {
            # Any other type of command conflict; throw error.
            throw
        }
    } catch {
        # Inform the user about the alias conflict and where to resolve it.
        Write-Error "Alias ""$tmpAliasName"" is already in use by ""$((Get-Command -Name $tmpAliasName).ReferencedCommand.Name)"" or another command. Please change the alias name in the script: ""$tmpCmdPath""" -ErrorAction Stop
    } finally {
        # Clean up temporary variables regardless of success or failure.
        Remove-Variable -Name "tmpAliasName" -Force
        Remove-Variable -Name "tmpCmdName" -Force
    }
} else {
    # If no alias exists, create it.
    Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
        | ForEach-Object {
            Write-Host "$($_.DisplayName) (created)" -ForegroundColor Green # Confirm alias creation
        }
    # Clean up temporary variables.
    Remove-Variable -Name "tmpAliasName" -Force
    Remove-Variable -Name "tmpCmdName" -Force
}
