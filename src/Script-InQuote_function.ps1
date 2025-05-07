<#
.SYNOPSIS
    Script-InQuote (Alias:qscr) - 

    default: Replace spaces to underscores only within strings
             enclosed in double quotes.

    PS> echo 'aaa "b b b" ccc' | Script-InQuote -From " " -To "_"

        aaa "b_b_b" ccc


    Function behavior:

    Note that this function allows to specify arbitrary types
    and numbers of enclosing characters using -Quote or -PunctuationMarks,
    but it does not differentiate between the types of enclosing characters.
    This function reads the input line by line, from left to right,
    character by character, treating the odd-numbered enclosing characters
    found as opening brackets and the even-numbered enclosing characters
    found as closing brackets.

.NOTES
    about_Regular_Expressions - PowerShell
    https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_regular_expressions

    Regular Expression Language - Quick Reference - .NET
    https://learn.microsoft.com/en-us/dotnet/standard/base-types/regular-expression-language-quick-reference

.LINK
    Script-InQuote, csv2txt

.EXAMPLE
    # Read from standard input and transform
    $logEntries = @(
       '192.168.1.1 - - [25/Mar/2025:06:45:00 +0900] "GET /index.html HTTP/1.1" 200 1234',
       '203.0.113.12 - - [25/Mar/2025:06:45:02 +0900] "POST /api/data HTTP/1.1" 500 432',
       '198.51.100.42 - - [25/Mar/2025:06:45:04 +0900] "PUT /upload HTTP/1.1" 201 5678'
    )

    # Replace spaces to underscores only within strings enclosed in double quotes.
    $logEntries | qscr -Function { %{ $_ -replace ' ', '@@@'}}

    192.168.1.1 - - [25/Mar/2025:06:45:00 +0900] "GET@@@/index.html@@@HTTP/1.1" 200 1234
    203.0.113.12 - - [25/Mar/2025:06:45:02 +0900] "POST@@@/api/data@@@HTTP/1.1" 500 432
    198.51.100.42 - - [25/Mar/2025:06:45:04 +0900] "PUT@@@/upload@@@HTTP/1.1" 201 5678

#>
function Script-InQuote {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True, Position=0)]
        [Alias('f')]
        [scriptblock] $Function
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
                    # apply function to the string
                    [string[]] $comAry = @()
                    [string[]] $comAry += '[string] $replaced = $currentQuote'
                    [string[]] $comAry += $Function.ToString().Trim()
                    [string[]] $comAry += 'Out-String -Stream'
                    [string] $com = $comAry -join " | "
                    Write-Debug "$com"
                    Invoke-Expression -Command $com
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
[String] $tmpAliasName = "qscr"
[String] $tmpCmdName   = "Script-InQuote"
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
