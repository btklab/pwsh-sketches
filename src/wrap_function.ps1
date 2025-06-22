<#
.SYNOPSIS
    wrap - Wrap each fields in specified format.

    "*" is placeholder

        "A B C D" | wrap '[*]'
        [A] [B] [C] [D]
        
        "A B C D" | wrap '[?]' -Placeholder '?'
        [A] [B] [C] [D]
        
        "A B C D" | wrap '[*]' -fs "_"
        [A B C D]

        "ABCD" | wrap '[*]' -fs ''
        [A][B][C][D]


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

.EXAMPLE
    "A B C D" | wrap '[*]'
    [A] [B] [C] [D]

    "A B C D" | wrap '[?]' -Placeholder '?'
    [A] [B] [C] [D]

    "A B C D" | wrap '[*]' -fs "_"
    [A B C D]

    "ABCD" | wrap '[*]' -fs ""
    [A][B][C][D]

.EXAMPLE
    "A B C D","E F G H" | wrap '<td>*</td>' | addt '<table>','<tr>' | addb '</tr>','</table>'
    <table>
    <tr>
    <td>A</td> <td>B</td> <td>C</td> <td>D</td>
    <td>E</td> <td>F</td> <td>G</td> <td>H</td>
    </tr>
    </table>

.LINK
    flat, rev2, addt, addb, addr, addl

#>
function wrap {

    param (
        [Parameter( Mandatory=$False, Position=0 )]
        [Alias('f')]
        [string] $Format,
        
        [Parameter( Mandatory=$False )]
        [Alias('p')]
        [string] $Placeholder = '*',
        
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
        # private functions

    }

    process {
        [string] $readLine = [string] $_
        if ( $readLine -eq '' ){
            # skip empty line
            Write-Output ''
            return
        }
        if ( $emptyDelimiterFlag ){
            [string[]] $splitReadLine = $readLine.ToCharArray()
        } else {
            [string[]] $splitReadLine = $readLine.Split( $iDelim )
        }
        [string[]] $tmpAry = foreach ( $l in $splitReadLine ){
                "$Format".Replace($Placeholder, $l)
            }
        [string] $writeLine = $tmpAry -join $oDelim
        Write-Output $writeLine
    }
}

