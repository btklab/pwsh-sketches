<#
.SYNOPSIS
    stair - Stair columns separated by spaces.

.DESCRIPTION

    The main design pattern of this command was abstracted from
    greymd(Yasuhiro, Yamada)'s "egzact",
    Here is the original copyright notice for "egzact":
    
        The MIT License Copyright (c) 2016 Yasuhiro, Yamada
        https://github.com/greymd/egzact/blob/master/LICENSE

.PARAMETER Delimiter
    Field separator. -fs
    Default value is space " ".

.PARAMETER InputDelimiter
    Input field separator. -ifs
    If fs is already set, this option is primarily used.

.PARAMETER OutoputDelimiter
    Output field separator. -ofs
    If fs is already set, this option is primarily used.

.EXAMPLE
    "A B C D" | stair

    A
    A B
    A B C
    A B C D

.EXAMPLE
    "A B C D" | stair -r

    D
    C D
    B C D
    A B C D

.EXAMPLE
    "A B C D E" | stair | stair -r
    
    A
    B
    A B
    C
    B C
    A B C
    D
    C D
    B C D
    A B C D
    E
    D E
    C D E
    B C D E
    A B C D E

#>
function stair {
    param (
        [Parameter(Mandatory=$False)]
        [Alias('r')]
        [switch] $Reverse,

        [Parameter(Mandatory=$False)]
        [Alias('fs')]
        [string] $Delimiter = ' ',

        [Parameter(Mandatory=$False)]
        [Alias('ifs')]
        [string] $InputDelimiter,

        [Parameter(Mandatory=$False)]
        [Alias('ofs')]
        [string] $OutputDelimiter,

        [parameter(Mandatory=$False,ValueFromPipeline=$True)]
        [string[]] $InputText
    )
    begin {
        # set input/output delimiter
        if ( $InputDelimiter -and $OutputDelimiter ){
            [string] $iDelim = $InputDelimiter
            [string] $oDelim = $OutputDelimiter
        } elseif ( $InputDelimiter ){
            [string] $iDelim = $InputDelimiter
            [string] $oDelim = $InputDelimiter
        } elseif ( $OutputDelimiter ){
            [string] $iDelim = $Delimiter
            [string] $oDelim = $OutputDelimiter
        } else {
            [string] $iDelim = $Delimiter
            [string] $oDelim = $Delimiter
        }
        # test is iDelim -eq ''?
        if ($iDelim -eq ''){
            [bool] $emptyDelimiterFlag = $True
        } else {
            [bool] $emptyDelimiterFlag = $False
        }
        # init variable
    }
    process {
        [string] $line = [string] $_
        if ( $emptyDelimiterFlag ){
            [string[]] $splitLine = $line.ToCharArray()
        } else {
            [string[]] $splitLine = $line.Split( $iDelim )
        }
        if ( $Reverse ){
            [int] $cnt = -1
            #[int] $cnt = $splitLine.Count
            foreach ($s in $splitLine){
                Write-Output $($splitline[$cnt..-1] -join $oDelim)
                $cnt--
            }
        } else {
            [int] $cnt = 0
            foreach ($s in $splitLine){
                Write-Output $($splitline[0..$cnt] -join $oDelim)
                $cnt++
            }
        }
    }
}
