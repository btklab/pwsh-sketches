<#
.SYNOPSIS
    combi2 - Generates combinations.

    Combination of 2 from "n".

    Usage
        cat input | combi2

    Example
        "A B C" | combi2
        A B
        A C
        B C

.DESCRIPTION

    The main design pattern of this command was abstracted from
    greymd(Yasuhiro, Yamada)'s "egzact",
    Here is the original copyright notice for "egzact": 
    
        The MIT License Copyright (c) 2016 Yasuhiro, Yamada
        https://github.com/greymd/egzact/blob/master/LICENSE


.PARAMETER Delimiter
    Input/Output field separator.
    Alias: -fs
    Default value is space " ".

.PARAMETER InputDelimiter
    Input field separator.
    Alias: -ifs
    If fs is already set, this option is primarily used.

.PARAMETER OutoputDelimiter
    Output field separator.
    Alias: -ofs
    If fs is already set, this option is primarily used.

.LINK
    perm, combi, dcombi, combi2

.EXAMPLE
    Write-Output "A B C" | combi2
    A B
    A C
    B C

    Write-Output "A B C" | combi 2
    A B
    A C
    B C

#>
function combi2 {

    param (
        [Parameter( Mandatory=$False )]
        [Alias('fs')]
        [string] $Delimiter = ' ',
        
        [Parameter( Mandatory=$False )]
        [Alias('ifs')]
        [string] $InputDelimiter,
        
        [Parameter( Mandatory=$False )]
        [Alias('ofs')]
        [string] $OutputDelimiter,
        
        [parameter( Mandatory=$False, ValueFromPipeline=$True )]
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
        # create zero-padding string
        [string] $strZero = '0' * $Num
    }

    process {
        # init variables
        [string] $writeLine = ''
        [string] $readLine = [string] $_
        if ( $emptyDelimiterFlag ){
            [string[]] $splitReadLine = $readLine.ToCharArray()
        } else {
            [string[]] $splitReadLine = $readLine.Split( $iDelim )
        }
        # main
        for( $i = 0; $i -lt $splitReadLine.Count; $i++ ){
            for( $j = 0; $j -lt $splitReadLine.Count; $j++ ){
                if ( $splitReadLine[$i] -lt $splitReadLine[$j]){
                    [string] $writeLine = @( $splitReadLine[$i,$j] ) -join $oDelim
                    Write-Output $writeLine
                    [string] $writeLine = ''
                }
            }
        }
    }

}
