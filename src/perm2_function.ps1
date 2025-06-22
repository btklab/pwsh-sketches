<#
.SYNOPSIS
    perm2 - Permutation of 2 from "n".

    By default, it reads input as space-delimited tokens.

    Usage
        "A B C" | perm2

    Example
        "A B C" | perm2
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
    perm, combi, dcombi, perm2

.EXAMPLE
    Write-Output "A B C" | perm2
    A B
    A C
    B A
    B C
    C A
    C B

#>
function perm2 {

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
        $hash = @{}
        for( $i = 0; $i -lt $splitReadLine.Count; $i++ ){
            for( $j = 0; $j -lt $splitReadLine.Count; $j++ ){
                $sortedKey = @( $splitReadLine[$i,$j] | Sort-Object ) -join "@"
                Write-Debug $sortedKey
                if ( $hash.ContainsKey( $sortedKey ) ){
                    [string] $writeLine = ''
                    continue
                } else {
                    $hash.add( $sortedKey , 0 )
                }
                [string] $writeLine = @( $splitReadLine[$i,$j] ) -join $oDelim
                Write-Output $writeLine
                [string] $writeLine = ''
            }
        }
    }

}
