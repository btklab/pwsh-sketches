<#
.SYNOPSIS
    Process-InQuote (Alias: qproc) - Runs a custom script only to strings enclosed in quotes.

.LINK
    csv2txt, csv2sqlite,
    Process-CsvColumn (csv2proc),
    Replace-InQuote (qsed),
    Process-InQuote (qproc)

.EXAMPLE
    # Read from standard input and transform
    $logEntries = @(
       '192.168.0.0 - - [25/Mar/2025:06:45:00 +0900] "GET /index.html HTTP/1.1" 200 1234',
       '192.168.0.1 - - [25/Mar/2025:06:45:02 +0900] "POST /api/data HTTP/1.1" 500 432',
       '192.168.0.2 - - [25/Mar/2025:06:45:04 +0900] "PUT /upload HTTP/1.1" 201 5678'
    )

    # Replace spaces to underscores only within strings enclosed in double quotes.
    $logEntries | qproc -ScriptBlock { $_ | %{ $_ -replace ' ', '@@@'}}

        192.168.0.0 - - [25/Mar/2025:06:45:00 +0900] "GET@@@/index.html@@@HTTP/1.1" 200 1234
        192.168.0.1 - - [25/Mar/2025:06:45:02 +0900] "POST@@@/api/data@@@HTTP/1.1" 500 432
        192.168.0.2 - - [25/Mar/2025:06:45:04 +0900] "PUT@@@/upload@@@HTTP/1.1" 201 5678

#>
function Process-InQuote {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [Alias('s')]
        [Alias('Script')]
        [scriptblock]$ScriptBlock
        ,
        [Parameter(Mandatory=$false)]
        [switch] $SkipBlank
        ,
        [Parameter(Mandatory=$false)]
        [Alias('q')]
        [string] $Quote = '"'
        ,
        [Parameter(Mandatory=$false)]
        [Alias('p')]
        [string[]] $PunctuationMarks
        ,
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [string[]] $TextObject
    )
    begin {
        # Begin block: Initialization process
        # private function
        function isPuncMark {
            param (
                [Parameter(Mandatory=$false)]
                [string] $c
            )
            [bool] $quartFlag = $False
            if ( $Quote -eq '' ) {
                # skip
            } else {
                if ( $c -eq $Quote ) {
                    $quartFlag = $true
                }
            }
            if ( $PunctuationMarks.Count -eq 0 ){
                # skip
            } else {
                if ( $c -in $PunctuationMarks ) {
                    $quartFlag = $true
                }
            }
            return $quartFlag
        }
    }
    process {
        # Process block: Input data processing
        [string] $line = $_
        if ( $line -eq '' ) {
            if ( $SkipBlank ){
                # skip empty line
            } else {
                Write-Output ''
            }
            return
        }
        [string[]] $lineAry = $line.ToCharArray()
        # Process each line
        [bool] $inQuote = $false
        [string] $currentQuote = ''
        [string] $writeLine = ''
        [string] $punctuationMark = ''
        for ($i = 0; $i -lt $lineAry.Count; $i++) {
            [string] $char = $lineAry[$i]
            Write-Debug "$char $(isPuncMark $char)"
            if ( isPuncMark $char ) {
                # Double quote found
                if ($inQuote) {
                    # End of quote
                    $inQuote = $false
                    # apply scriptblock to the quote enclosed string
                    try {
                        [string] $replaced = $ScriptBlock.InvokeWithContext($null, [psvariable]::new('_', $currentQuote))
                    } catch {
                        Write-Error $Error[0] -ErrorAction Stop
                    }
                    [string] $writeLine += $replaced
                    [string] $currentQuote = ''
                    [string] $writeLine += $char
                } else {
                    # Start of quote
                    [bool] $inQuote = $true
                    [string] $writeLine += $char
                }
            } else {
                # Not a double quote
                if ($inQuote) {
                    [string] $currentQuote += $char
                } else {
                    [string] $writeLine += $char
                }
            }
        }
        Write-Output $writeLine
    }
    end {
        # End block: Post-processing
        #  - Nothing specific
    }
}
# set alias
[String] $tmpAliasName = "qproc"
[String] $tmpCmdName   = "Process-InQuote"
[String] $tmpCmdPath = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath $($MyInvocation.MyCommand.Name) `
    | Resolve-Path -Relative
if ( $IsWindows ){ $tmpCmdPath = $tmpCmdPath.Replace('\' ,'/') }
# is alias already exists?
if ((Get-Command -Name $tmpAliasName -ErrorAction SilentlyContinue).Count -gt 0){
    try {
        if ( (Get-Command -Name $tmpAliasName).CommandType -eq "Alias" ){
            if ( (Get-Command -Name $tmpAliasName).ReferencedCommand.Name -eq $tmpCmdName ){
                Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
                    | ForEach-Object{
                        Write-Host "$($_.DisplayName)" -ForegroundColor Green
                    }
            } else {
                throw
            }
        } elseif ( "$((Get-Command -Name $tmpAliasName).Name)" -match '\.exe$') {
            Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
                | ForEach-Object{
                    Write-Host "$($_.DisplayName)" -ForegroundColor Green
                }
        } else {
            throw
        }
    } catch {
        Write-Error "Alias ""$tmpAliasName ($((Get-Command -Name $tmpAliasName).ReferencedCommand.Name))"" is already exists. Change alias needed. Please edit the script at the end of the file: ""$tmpCmdPath""" -ErrorAction Stop
    } finally {
        Remove-Variable -Name "tmpAliasName" -Force
        Remove-Variable -Name "tmpCmdName" -Force
    }
} else {
    Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
        | ForEach-Object {
            Write-Host "$($_.DisplayName)" -ForegroundColor Green
        }
    Remove-Variable -Name "tmpAliasName" -Force
    Remove-Variable -Name "tmpCmdName" -Force
}
