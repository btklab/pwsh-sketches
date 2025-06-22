<#
.SYNOPSIS
    perm - Permutation of "r" from "n".

    Maximum number of input columns is 10.
    By default, it reads input as space-delimited tokens.

    Usage
        "A B C" | perm <r>

    Example
        "A B C" | perm 2
        A B
        A C
        B A
        B C
        C A
        C B

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
    perm, combi, dcombi

.EXAMPLE
    Write-Output "A B C" | combi 2
    A B
    A C
    B C

    Write-Output "A B C" | perm 2
    A B
    A C
    B A
    B C
    C A
    C B

    Write-Output "A B C" | dcombi 2
    A A
    A B
    A C
    B A
    B B
    B C
    C A
    C B
    C C

    # equivalent to "combi 2" using dcombi
    Write-Output "A B C" | dcombi 2 | pawk -Pattern { $1 -lt $2 }
    A B
    A C
    B C

.EXAMPLE
    # Combinations of 0 and 1 from "0 0 0" to "1 1 1"
    Write-Output "0 0 0 1 1 1" | perm 3 | sort -Unique
    
    0 0 0
    0 0 1
    0 1 0
    0 1 1
    1 0 0
    1 0 1
    1 1 0
    1 1 1

#>
function perm {

    param (
        [Parameter( Mandatory=$False, Position=0 )]
        [ValidateRange(1,10)]
        [Alias('n')]
        [int] $Num = 1,
        
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
        # A combination of $Num selected form $BaseNum
        [int] $baseNum = $splitReadLine.Count
        if ( $baseNum -gt 10 ) {
            Write-Error "The number of fields has exceeded 10." -ErrorAction Stop
        }
        [int] $combiTotalNum = [math]::Pow($baseNum,$Num)
        
        # main
        for( $i = 0; $i -lt $combiTotalNum; $i++ ){
            [string] $baseNstr = ''
            [decimal] $base10Num = $i
            do {
                # quotient
                $div = ($base10Num - $base10Num % $baseNum) / $baseNum
                # remainder
                $mod = $base10Num % $baseNum
                # N-adic conversion string
                [string] $baseNstr = [string]$mod + [string]$baseNstr
                $base10Num = $div
            } while( $base10Num -ge $baseNum )
            if( $base10Num -ne 0 ){
                $baseNstr = [string]$div + [string]$baseNstr
            }
            
            # N-adic generation
            if( $i -eq 0 ){
                [string] $writeLine = [string] $baseNstr
            }else{
                [string] $writeLine = $writeLine + [string] $baseNstr
            }
            # N-adic zero padding and output
            [string[]] $splitNum = ([decimal]$writeLine).ToString("$strZero") -split ''
            ## test if each element is used once
            Write-Debug ([decimal]$writeLine).ToString("$strZero")
            [int] $NumOfAllElements = $splitNum.Count - 2
            [int] $NumOfInputElements = (([decimal]$writeLine).ToString("$strZero").GetEnumerator() | Sort-Object -Unique).Count
            if ( $NumOfAllElements -ne $NumOfInputElements ){
                [string] $writeLine = ''
                continue
            }
            [string] $writeLine = [string]($splitReadLine[($splitNum[1])])
            for( $k = 2; $k -lt $splitNum.Count - 1;$k++ ){
                [string] $writeLine = $writeLine + $oDelim + [string]($splitReadLine[($splitNum[$k])])
            }
            Write-Output $writeLine
            [string] $writeLine = ''
        }
    }

}
