<#
.SYNOPSIS
    rev2 - Reverse columns

    Reverse columns separated by space.
    Do not reverse strings in columns.

    Accepts only input from pipeline

    Usage:
        rev2 [-e]
    
    Option:
        -e: (echo) 入力データも出力する

.DESCRIPTION

    The main design pattern of this command was abstracted from
    greymd(Yasuhiro, Yamada)'s "egzact",
    Here is the original copyright notice for "egzact":
    
        The MIT License Copyright (c) 2016 Yasuhiro, Yamada
        https://github.com/greymd/egzact/blob/master/LICENSE

.LINK
    rev, rev2, stair, cycle


.EXAMPLE
    "01 02 03" | rev2
    03 02 01

.EXAMPLE
    "01 02 03" | rev2 -e
    01 02 03
    03 02 01

#>
function rev2 {
    Param(
        [parameter(Mandatory=$False)]
        [Alias('e')]
        [switch] $echo,

        [parameter(Mandatory=$False)]
        [Alias('d')]
        [string] $Delimiter = " ",

        [parameter(Mandatory=$False,
            ValueFromPipeline=$True)]
        [string[]]$Text
    )
    process {
        [string] $readLine = "$_".Trim()
        if ( $Delimiter -eq '' ){
            [string[]] $splitReadLine = $readLine.ToCharArray()
        } else {
            [string[]] $splitReadLine = $readLine.Split( $Delimiter )
        }
        if($echo){ Write-Output $readLine }
        [string] $writeLine = [string]::join($Delimiter, $splitReadLine[($splitReadLine.Count - 1)..0])
        Write-Output $writeLine
    }
}
