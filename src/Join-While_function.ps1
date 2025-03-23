<#
.SYNOPSIS
    Join-While (Alias:joinw) - Join lines while a specified regex is found.

    Concatenate lines while they match the specified regular expression or
    a blank line is encountered.

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

.PARAMETER SkipBlank
    If detect a blank line,
    output once there.

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
    # If -Regex "" is specified,
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
        [string]$Regex
        ,
        [Parameter(Mandatory=$False)]
        [string]$Delimiter = ' '
        ,
        [Parameter(Mandatory=$False)]
        [switch]$SkipBlank
        ,
        [Parameter(Mandatory=$False)]
        [switch]$AddCrLf
        ,
        [Parameter(Mandatory=$False)]
        [string[]]$Before
        ,
        [Parameter(Mandatory=$False)]
        [string[]]$After
        ,
        [parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string[]]$TextObject
    )
    begin{
        ## init var
        [int] $counter      = 0
        [bool] $bufFlag     = $False
        [Regex] $reg        = $Regex
        [string] $readLine  = ""
        [string] $writeLine = ""
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
        # skip blank
        if (($SkipBlank) -and ($readLine -eq '')) {
            if ($bufFlag) {
                Write-BeforeAndAfterOutput $writeLine
                $writeLine = ''
                $bufFlag = $False
            }
            Write-Output ""
            return
        }
        # don't skip blank
        if ($readLine -cmatch $reg){
            ## if ends with $Str
            if ($bufFlag){
                $writeLine += $Delimiter + $readLine
            }else{
                $writeLine = $readLine
            }
            $bufFlag = $True
        }else{
            ## if not ends with $Str
            if ($bufFlag){
                $writeLine = $writeLine + $Delimiter + $readLine
                $bufFlag = $False
            }else{
                $writeLine = $readLine
            }
            Write-BeforeAndAfterOutput $writeLine
            [string] $writeLine = ''
        }
    }
    end{
        # output
        if ($writeLine -ne '') {
            Write-BeforeAndAfterOutput $writeLine
        }
        if ($AddCrLf) {
            Write-Output ""
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
