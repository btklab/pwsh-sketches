<#
.SYNOPSIS
    Get-Gmail (Alias:gmail) - Connects to the Gmail retrieves a list of messages.

    Connects to the Gmail API using OAuth 2.0 and retrieves a list of messages from the user's account.
    
    Gmail API Setup Instructions:

    1. Go to Google Cloud Console https://console.cloud.google.com/
    2. Create a new project or select existing one
    3. Enable Gmail API: APIs & Services > Library > Search "Gmail API" > Enable
    4. Navigate to APIs & Services > OAuth consent screen
        - Fill in the required fields (App name, User support email, etc.)
        - UserType: External
    5. Set Scope: Data Access > Cerate Scope > Check "https://www.googleapis.com/auth/gmail.readonly"
    6. Create credentials: APIs & Services > Credentials > Create Credentials > OAuth 2.0 Client IDs
        - Application type: Desktop app
    7. Download the JSON credentials file
        - Place the credentials file in the same directory as this script
        - Rename it to 'gmail-credentials.json'
    8. Add test users: APIs & Services > OAuth consent screen > Test users
        - Add your Google account email to the list of test users
    9. AccessToken handling Tips
        - https://developers.google.com/workspace/gmail/api/quickstart/python


.DESCRIPTION
    The Get-Gmail function handles the OAuth 2.0 authentication process with the Google API to access Gmail.
    On the first run, it prompts the user to authenticate via a web browser and saves a refresh token to a file.
    Subsequent runs use the saved token to get a new access token without user interaction.

    This function allows filtering messages by one or more labels (e.g., 'INBOX', 'SENT', 'UNREAD', or custom labels).
    Switches like -UnRead, -Sent, and -Inbox can be combined with the -Label parameter.
    If no labels are specified, it defaults to 'INBOX'.

    This script is designed for readability and maintainability, following principles from "Readable Code".

.LINK
    Set-DotEnv, Get-Gmail, Get-Gcalendar

.PARAMETER From
    Filters messages to include only those sent from the specified email address(es).

.PARAMETER Body
    If specified, includes the full email body in the result.

.PARAMETER MaxResults
    The maximum number of email messages to retrieve. Default is 15.

.PARAMETER CredentialJsonPath
    Path to the 'gmail_credentials.json' file. Defaults to the script's directory.

.PARAMETER TokenFilePath
    Path to save/load the 'gmail_refresh_token.json' file. Defaults to the script's directory.

.EXAMPLE
    Get-Gmail -From "newsletter@example.com" -MaxResults 10
    # Retrieves the latest 10 messages from "newsletter@example.com" in your INBOX.

.EXAMPLE
    Get-Gmail -Body
    # Retrieves the latest 15 messages from your INBOX, including the full email body.

.OUTPUTS
    An array of PSCustomObject, each representing an email with its metadata.

.NOTES
    Author: Gemini
    Date: 2025-07-05
    Requires PowerShell 5.1 or later.
#>
function Get-Gmail {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [int[]] $Id,

        [Parameter(Mandatory = $false)]
        [Alias('cred', 'credentials')]
        [string]$CredentialJsonPath = "./gmail_credentials.json",

        [Parameter(Mandatory = $false)]
        [Alias('token', 'refreshToken')]
        [string]$TokenFilePath = "./gmail_refresh_token.json",

        [Parameter(Mandatory = $false)]
        [Alias('envCred', 'envCredentials')]
        [string]$EnvNameCredentialJson = "GMAIL_CREDENTIALS",

        [Parameter(Mandatory = $false)]
        [Alias('envToken', 'envRefreshToken')]
        [string]$EnvNameToken = "GMAIL_REFRESH_TOKEN",

        [Parameter(Mandatory = $false)]
        [Alias('envAddr')]
        [string]$EnvAddress = "GMAIL_ADDR",

        [Parameter(Mandatory = $false)]
        [string]$EnvFilePath = "./.myenv",

        [Parameter(Mandatory = $false)]
        [Alias('b')]
        [switch]$Body,

        [Parameter(Mandatory = $false)]
        [switch]$InvokeLink,

        [Parameter(Mandatory = $false)]
        [Alias('f')]
        [string[]]$From,

        [Parameter(Mandatory = $false)]
        [switch]$Ticket,

        [Parameter(Mandatory = $false)]
        [Alias('t')]
        [switch]$Todo,

        [Parameter(Mandatory = $false)]
        [Alias('s')]
        [string]$Subject,

        [Parameter(Mandatory = $false)]
        [datetime]$Start = (Get-Date).AddDays(-31),

        [Parameter(Mandatory = $false)]
        [Alias('max','m')]
        [int]$MaxResults = 10
    )
    # Set default values for parameters.
    if ( $Ticket -or $Todo ) {
        [string] $Subject = '^\+|^\([A-Z]\) '
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
    # Helper function to convert Gmail's InternalDate to local DateTime.
    function Convert-GmailInternalDate {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
            [long]$InternalDate
        )
        process {
            try {
                $epoch = [datetime]::UnixEpoch
                $dateTimeUtc = $epoch.AddMilliseconds($InternalDate)
                return $dateTimeUtc.ToLocalTime()
            } catch {
                Write-Error "Failed to convert InternalDate: $_"
            }
        }
    }
    # Helper function to extract URIs from text.
    function Extract-UriAsArray {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
            [string]$Text
        )
        process {
            $pattern = 'https?://[^ ]+'
            $matches = [regex]::Matches($Text, $pattern)
            return $matches | ForEach-Object { $_.Value } | Sort-Object -Unique
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
        #[string]$myenvPath = Join-Path $PSScriptRoot "$myenvPath"
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
    $MailAddr = Get-ChildItem -LiteralPath "Env:" `
        | Where-Object name -eq '$EnvAddress' `
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
        $refreshTokenData = $RefreshToken `
            | ConvertTo-SecureString
    } else {
        Write-Verbose "Do not found ""ls Env:\$EnvNameToken"""
        if ( -not (Test-Path -LiteralPath $TokenFilePath) ) {
            Write-Error "Refresh token file not found at ""$TokenFilePath"". Please follow the setup instructions." -ErrorAction Continue
        }
        Write-Verbose "Loading refresh token from ""file: $TokenFilePath"""
        $refreshTokenData = Get-Content -LiteralPath "$TokenFilePath" -Encoding utf8 `
            | ConvertTo-SecureString
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
            Remove-Item -LiteralPath $TokenFilePath -Confirm -ErrorAction SilentlyContinue
        }
    }

    # If no access token, perform the full OAuth 2.0 flow.
    if (-not $accessToken) {
        Write-Host "Starting first-time authentication. A browser window will open."
        Write-Host "Please log in and grant permission to the application."

        $scope = "https://www.googleapis.com/auth/gmail.readonly"
        $authUrl = "$authUri`?scope=$scope&redirect_uri=$redirectUri&response_type=code&client_id=$clientId"

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

    # --- Step 3: Call the Gmail API ---
    if (-not $accessToken) {
        throw "Failed to obtain an access token. Cannot proceed."
    }

    # Build the search query. Always search in INBOX.
    $queryParts = New-Object System.Collections.Generic.List[string]
    #$queryParts.Add("in:inbox")

    if ($PSBoundParameters.ContainsKey('From')) {
        $fromQuery = "from:(" + ($From -join " OR ") + ")"
        #$fromQuery = "from:(" + $From + ")"
        $queryParts.Add($fromQuery)
    }
    
    # URL-encode the final query string.
    if ( $queryParts.ToArray().Count -eq 0 ) {
        [string] $encodedQuery = [uri]::EscapeDataString($queryParts.ToArray() -join " ")
    } else {
        [string] $encodedQuery = ""
    }
    
    Write-Verbose "Querying Gmail with: $($queryParts -join ' ')"
    $gmailApiUrl = "https://www.googleapis.com/gmail/v1/users/me/messages?labelIds=INBOX&maxResults=$MaxResults&includeSpamTrash=false"
    if ( $encodedQuery -ne "" ) {
        $gmailApiUrl += "&q=$encodedQuery"
    }
    $headers = @{ "Authorization" = "Bearer $accessToken" }

    try {
        [int]$IdCounter = 0
        
        Write-Verbose "Fetching message list from: $gmailApiUrl"
        $response = Invoke-RestMethod -Uri $gmailApiUrl -Headers $headers -Method Get
        
        if (-not $response.messages) {
            #Write-Host "No messages found matching your criteria."
            return
        }

        if ( $Id.Count -gt 0 ) {
            [int]$IdMax = $Id | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
        }

        foreach ($message in $response.messages) {
            if ( $Id.Count -gt 0 -and $IdCounter -ge $IdMax ) {
                Write-Verbose "Skipping message with ID $IdCounter as it is not in the specified Id list."
                break
            }

            [string]$apiUrl = "https://www.googleapis.com/gmail/v1/users/me/messages/$($message.id)?format=full"
            
            Write-Debug "Fetching details for message ID $($message.id)"
            $msg = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get
            
            # Parse headers into a more accessible hashtable.
            $msgHeaders = @{}
            foreach ($header in $msg.payload.headers) {
                $msgHeaders[$header.name] = $header.value
            }
            # Filter by Subject if specified.
            if ( $Subject ){
                if ( $msgHeaders["Subject"] -notmatch $Subject ){
                    Write-Verbose "Skipping message with Subject '$($msgHeaders["Subject"])' as it does not match the specified Subject filter."
                    continue
                }
            }
            [datetime]$datetime = Convert-GmailInternalDate -InternalDate $msg.internalDate
            if ( $datetime -lt $Start ) {
                Write-Verbose "Skipping message with Date '$($datetime.ToString('yyyy-MM-dd HH:mm'))' as it is older than the specified Start date."
                continue
            }
            
            # Construct the final output object.
            $IdCounter++
            if ( $Id.Count -gt 0 -and $Id -notcontains $IdCounter ) {
                Write-Verbose "Skipping message with ID $IdCounter as it is not in the specified Id list."
                continue
            }
            $email = [ordered]@{
                Id           = $IdCounter
                Date         = $datetime.ToString('yyyy-MM-dd')
                Week         = $datetime.ToString('(ddd)')
                u            = if ($msg.labelIds -contains "UNREAD") { '*' } else { $null }
                Subject      = $msgHeaders["Subject"]
                Snippet      = $msg.snippet
                Label        = $msg.labelIds
                From         = $msgHeaders["From"]
                To           = $msgHeaders["To"]
                ThreadId     = $msg.threadId
                Size         = $msg.sizeEstimate
                InternalDate = $msg.internalDate
                DateTime     = $datetime.ToString('yyyy-MM-dd HH:mm')
                Time         = $datetime.ToString('HH:mm')
            }
            
            # Decode body if requested and available.
            if ($Body -and $msg.payload.body.data) {
                $email.Body = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($msg.payload.body.data.Replace('-', '+').Replace('_', '/')))
            }
            
            # Extract links from body or snippet.
            $textToScanForLinks = if ($email.Body) { $email.Body } else { $msg.snippet }
            $email.Link = Extract-UriAsArray -Text $textToScanForLinks

            if ( $Todo ){
                [string[]] $todoAry = @()
                [string] $tmpSubject = $msgHeaders["Subject"]
                if ( $tmpSubject -match '^\([A-Z]\) .*$' ){
                    [string] $subjectPriority = $tmpSubject -replace '^(\([A-Z]\)) (.*)$', '$1'
                    [string] $subjectBody     = $tmpSubject -replace '^(\([A-Z]\)) (.*)$', '$2'
                    [string[]] $todoAry += $subjectPriority
                } else {
                    [string] $subjectBody     = $tmpSubject
                }
                [string[]] $todoAry += $datetime.ToString('yyyy-MM-dd')
                [string[]] $todoAry += $subjectBody.Trim()
                [string] $todoStr = $todoAry -join ' '
                Write-Output $todoStr
                # output links only specific to todo items
                if ( $email.Link.Count -gt 0 -and $Id.Count -gt 0 ) {
                    foreach ($todoLink in $email.Link) {
                        Write-Output " link: $todoLink"
                    }
                }
            } else {
                [PSCustomObject]$email
            }
            # If InvokeLink is true, open links in the default browser.
            if ($InvokeLink -and $email.Link.Count -gt 0) {
                foreach ($extUri in $email.Link) {
                    Write-Verbose "Opening link: $extUri"
                    try { Start-Process $extUri } catch { Write-Warning "Failed to open link: $_" }
                }
            }
        }
    }
    catch {
        $errorResponse = $_.Exception.Response.GetResponseStream()
        $streamReader = New-Object System.IO.StreamReader($errorResponse)
        $errorBody = $streamReader.ReadToEnd()
        Write-Error "An error occurred while calling the Gmail API: $errorBody" -ErrorAction Stop
    }
}

# set alias
# This block automatically sets an alias for the function upon script load.
[String] $tmpAliasName = "gmail"
[String] $tmpCmdName = "Get-Gmail"

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
