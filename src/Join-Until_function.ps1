<#
.SYNOPSIS
    Join-Until (Alias:joinu) - Join lines until a specified regex is found.

    Concatenate lines until they match the specified regular expression.

    Param:
      -TrimOnlyInJoin ... Trim only the connected lines before joining.
      -DisableTrim    ... Disable Trim all lines before and after joining.

.LINK
    Join-While, Join-Until, Trim-EmptyLine,
    Join-Step, Join-BlankLine,
    list2txt, csv2txt

.EXAMPLE
    # Concatenate lines until a comma appears at the end.
    @("hogehoge and",
    "fugafuga.",
    "piyopiyo,",
    "hogefuga."
    ) | joinu ',$'

        hogehoge and fugafuga.
        piyopiyo, hogefuga.


.EXAMPLE
    cat data.txt

    # data
    
    [date]
        2024-10-24
    
    [title]
    
    [author]
        btklab,
        fuga
    
    [summary]
        summary-1
        summary-2
        summary-3
    
    [link]
        link-1
        link-2
        
    cat data.txt | joinu '\['

    # data
    [date] 2024-10-24
    [title]
    [author] btklab, fuga
    [summary] summary-1 summary-2 summary-3
    [link] link-1 link-2

.EXAMPLE
    # skip header
    cat data.txt | joinu '\[' -SkipHeader

    [date] 2024-10-24
    [title]
    [author] btklab, fuga
    [summary] summary-1 summary-2 summary-3
    [link] link-1 link-2

.EXAMPLE
    # delete match
    cat data.txt | joinu '\[([^]]+)\]' -Delete

    # data
    2024-10-24

    btklab, fuga
    summary-1 summary-2 summary-3
    link-1 link-2

.EXAMPLE
    # replace match
    cat data.txt | joinu '\[([^]]+)\]' -Replace '$1:'

    # data
    date: 2024-10-24
    title:
    author: btklab, fuga
    summary: summary-1 summary-2 summary-3
    link: link-1 link-2

.EXAMPLE
    # Replace first delimiter
    cat data.txt | joinu '\[' -Delimiter ',' -ReplaceFirstDelimiter ": "

    # data
    [date]: 2024-10-24
    [title]
    [author]: btklab,,fuga
    [summary]: summary-1,summary-2,summary-3
    [link]: link-1,link-2


.EXAMPLE
    # insert empty line for each line
    cat data.txt | joinu '\[([^]]+)\]' -After "" | juni

    1 # data
    2
    3 [date] 2024-10-24
    4
    5 [title]
    6
    7 [author] btklab, fuga
    8
    9 [summary] summary-1 summary-2 summary-3
    10
    11 [link] link-1 link-2
    12

.EXAMPLE
    # concatenates lines by item,
    # deletes item names,
    # and outputs in one tab-delimited line
    # for spread sheet
    (cat data.txt | joinu '\[([^]]+)\]' -Delete -SkipHeader) -join "`t"

    Output:
    
        2024-10-24<TAB><TAB>btklab, fuga<TAB>summary-1 summary-2 summary-3<TAB>link-1 link-2

#>
function Join-Until {

    [CmdletBinding()]
    param (
        [Parameter(
            HelpMessage="Search regex",
            Mandatory=$False,
            Position = 0
        )]
        [Alias('r')]
        [String] $Regex = "."
        ,
        [Parameter(
            HelpMessage="Output delimiter",
            Mandatory=$False
        )]
        [Alias('d')]
        [String] $Delimiter = " "
        ,
        [Parameter(
            HelpMessage="Escape regex",
            Mandatory=$False
        )]
        [Switch] $EscapeRegex
        ,
        [Parameter(
            HelpMessage="Trim only injoin line",
            Mandatory=$False
        )]
        [Switch] $TrimOnlyInJoin
        ,
        [Parameter(
            HelpMessage="Replace the 1st Delimiter",
            Mandatory=$False
        )]
        [String] $ReplaceFirstDelimiter
        ,
        [Parameter(
            HelpMessage="Disable Trim line",
            Mandatory=$False
        )]
        [Switch] $DisableTrim
        ,
        [Parameter(
            Mandatory=$False
        )]
        [Switch] $DisableBlankDelimiter
        ,
        [Parameter(
            HelpMessage="Skip header until a specified string is found",
            Mandatory=$False
        )]
        [Switch] $SkipHeader
        ,
        [Parameter(
            HelpMessage="Delete matched strings",
            Mandatory=$False
        )]
        [Alias('del')]
        [Switch] $Delete
        ,
        [Parameter(
            HelpMessage="Replace matched strings",
            Mandatory=$False
        )]
        [Alias('rm')]
        [String] $Replace
        ,
        [Parameter(
            HelpMessage="Insert Before",
            Mandatory=$False
        )]
        [Alias('b')]
        [String[]] $Before
        ,
        [Parameter(
            HelpMessage="Insert After",
            Mandatory=$False
        )]
        [Alias('a')]
        [String[]] $After
        ,
        [parameter(
            HelpMessage="Input",
            Mandatory=$False,
            ValueFromPipeline=$True
        )]
        [String[]] $InputText
    )

    begin {
        # set variables
        [Int] $rowCounter = 0
        if ($EscapeRegex) {
            [regex] $reg = [Regex]::Escape($Regex)
        } else {
            [regex] $reg = $Regex
        }
        [Bool] $firstMatch = $False
        [Bool] $inJoin = $True
        [String[]] $tempLineAry = @()
        $tempAryList = New-Object 'System.Collections.Generic.List[System.String]'
        ## private function
        function Write-BeforeAndAfterOutput ([string] $line) {
            if ( $Before.Count -gt 0 ){
                Write-Output $Before
            }
            if ( $ReplaceFirstDelimiter ){
                [regex] $escapedDelimiter = [Regex]::Escape($Delimiter)
                $line = $escapedDelimiter.Replace($line, $ReplaceFirstDelimiter, 1)
            } else {
                $line = $line
            }
            Write-Output $line
            if ( $After.Count -gt 0 ){
                Write-Output $After
            }
            return
        }
    }
    process {
        $rowCounter++
        [String] $readLine = [String] $_
        if ( $readLine -match $reg ){
            [Bool] $firstMatch = $True
            [Bool] $inJoin = $False
        } else {
            [Bool] $inJoin = $True
        }
        if ( -not $DisableTrim ){
            [String] $readLine = $readLine.Trim()
        } elseif ( $TrimOnlyInJoin -and $inJoin ){
            [String] $readLine = $readLine.Trim()
        }
        ## test readline
        Write-Debug "firstMatch: $firstMatch"
        if ( $SkipHeader -and -not $firstMatch ){
            return
        }
        if ( $readLine -match '^\s*$'){
            if ( $DisableBlankDelimiter ){
                return
            } else {
                #Write-Output ''
                return
            }
        }
        if ( $readLine -match $reg ){
            ## output stocked lines
            [String[]] $tempLineAry = $tempAryList.ToArray()
            if ( $tempLineAry.Count -gt 0 ){
                [String] $writeLine = $tempLineAry -join $Delimiter
                if ( -not $DisableTrim ){
                    $writeLine = $writeLine.Trim()
                }
                Write-BeforeAndAfterOutput $writeLine
            }
            ## flush
            [String[]] $tempLineAry = @()
            $tempAryList = New-Object 'System.Collections.Generic.List[System.String]'
        }
        ## replace match
        if ( $Replace ){
            [String] $readLine = $readLine -replace $reg, $Replace
        } elseif ( $Delete ){
            [String] $readLine = $readLine -replace $reg, ''
        }
        $tempAryList.Add( $readLine )
    }

    end {
        ## output stocked lines
        [String[]] $tempLineAry = $tempAryList.ToArray()
        if ( $tempLineAry.Count -gt 0 ){
            [String] $writeLine = $tempLineAry -join $Delimiter
            if ( -not $DisableTrim ){
                $writeLine = $writeLine.Trim()
            }
            Write-BeforeAndAfterOutput $writeLine
        }
        ## flush
        [String[]] $tempLineAry = @()
        $tempAryList = New-Object 'System.Collections.Generic.List[System.String]'
    }
}
# set alias
[String] $tmpAliasName = "joinu"
[String] $tmpCmdName   = "Join-Until"
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
