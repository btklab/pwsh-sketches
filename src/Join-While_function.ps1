<#
.SYNOPSIS
    Join-While (Alias:joinw) - Join lines while a specified regex is found.

    Concatenate lines while they match the specified regular expression or
    a blank line is encountered.

    Param:
      -TrimOnlyInJoin ... Trim only the connected lines before joining.
      -DisableTrim    ... Disable Trim all lines before and after joining.

    Note that ending character string treated as regular expressions.
    Use escape mark "\" to search for symbols as character, for example:
    
        "." to "\."
        "-" to "\-"
        "$" to "\$"
        "\" to "\\"

.LINK
    Join-While, Join-Until, Trim-EmptyLine, list2txt, csv2txt

.PARAMETER Regex
    Specify the end string that coonects
    the next line with a regular expression.

.PARAMETER Delimiter
    Specifies delimiter.
    
    Default: ' '

.PARAMETER AddCrLf
    Insert a blank line end of input.

.EXAMPLE
    # Concatenate lines until a comma appears at the end.
    # Output delimiter
    @("hogehoge and",
    "fugafuga.",
    "piyopiyo,",
    "hogefuga."
    ) | joinw ',$' -Delimiter " "

    hogehoge and
    fugafuga.
    piyopiyo, hogefuga.

    # Note:
    #
    # If -Regex '' or '^' is specified,
    # concatenate all lines.
    #
    # If -Regex "."  is specified,
    # concatenate lines by blank lines

.EXAMPLE
    cat data.txt

    Output:

        bumon-A
        filter
        17:45 2017/05/10
        hoge
        fuga

        bumon-B
        eva
        17:46 2017/05/10
        piyo
        piyo

        bumon-C
        tank
        17:46 2017/05/10
        fuga
        fuga
    
    cat data.txt | joinw . -d "`t"

    Output:
    
        bumon-A filter  17:45 2017/05/10        hoge    fuga
        bumon-B eva     17:46 2017/05/10        piyo    piyo
        bumon-C tank    17:46 2017/05/10        fuga    fuga
    
        Description.
        =============
        Converts blank line delimited records to tab delimited records.

#>
function Join-While {
    Param(
        [Parameter(Mandatory=$False, Position=0)]
        [Alias('r')]
        [string]$Regex
        ,
        [Parameter(Mandatory=$False)]
        [Alias('d')]
        [string]$Delimiter = ' '
        ,
        [Parameter(Mandatory=$False)]
        [switch]$TrimOnlyInJoin
        ,
        [Parameter(Mandatory=$False)]
        [switch]$DisableTrim
        ,
        [Parameter(Mandatory=$False)]
        [switch]$DisableBlankDelimiter
        ,
        [Parameter(Mandatory=$False)]
        [switch]$AddCrLf
        ,
        [Parameter(Mandatory=$False)]
        [Alias('b')]
        [string[]]$Before
        ,
        [Parameter(Mandatory=$False)]
        [Alias('a')]
        [string[]]$After
        ,
        [parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string[]]$TextObject
    )
    begin{
        ## init var
        [int] $counter      = 0
        [Regex] $reg        = $Regex
        [string] $readLine  = ""
        [string] $writeLine = ""
        [bool] $inJoin      = $False
        ## private function
        function Write-BeforeAndAfterOutput ([string] $line) {
            if ( $Before.Count -gt 0 ){
                Write-Output $Before
            }
            Write-Output $line
            if ( $After.Count -gt 0 ){
                Write-Output $After
            }
            return
        }
    }
    process{
        # increment counter
        $counter++
        # read a line
        [string] $readLine = $_
        if ( $readLine -match $reg ){
            if ( $inJoin ) {
                [bool] $inJoin      = $True
                [bool] $secondMatch = $True
            } else {
                [bool] $inJoin      = $True
                [bool] $secondMatch = $False
            }
        } else {
            [bool] $secondMatch = $False
        }
        if ( -not $DisableTrim ){
            $readLine = $readLine.Trim()
        } elseif ( $TrimOnlyInJoin -and $nextMatch ){
            $readLine = $readLine.Trim()
        }
        # skip blank
        if (( -not $DisableBlankDelimiter ) -and ($readLine -match '^\s*$')) {
            if ($inJoin) {
                if ( -not $DisableTrim ) {
                    $writeLine = $writeLine.Trim()
                }
                Write-BeforeAndAfterOutput $writeLine
                [string] $writeLine = ''
                [bool] $inJoin = $False
            }
            #Write-Output ''
            return
        }
        # do not skip blank
        if ($readLine -match $reg){
            ## if ends with $Str
            if ($inJoin){
                $writeLine += $Delimiter + $readLine
            }else{
                $writeLine = $readLine
            }
            [bool] $inJoin = $True
        }else{
            ## if not ends with $Str
            if ($inJoin){
                [string] $writeLine = $writeLine + $Delimiter + $readLine
                [bool] $inJoin = $False
            }else{
                [string] $writeLine = $readLine
            }
            if ( -not $DisableTrim ) {
                $writeLine = $writeLine.Trim()
            }
            Write-BeforeAndAfterOutput $writeLine
            [string] $writeLine = ''
        }
    }
    end{
        # output
        if ($writeLine -ne '') {
            if ( -not $DisableTrim ) {
                [string] $writeLine = $writeLine.Trim()
            }
            Write-BeforeAndAfterOutput $writeLine
        }
        if ($AddCrLf) {
            Write-Output ''
        }
    }
}
# set alias
[String] $tmpAliasName = "joinw"
[String] $tmpCmdName   = "Join-While"
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
