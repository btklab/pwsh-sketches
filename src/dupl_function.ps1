<#
.SYNOPSIS
    dupl- Duplicates input objects by a specified count.

.DESCRIPTION
    This function duplicates each input object the number of times
    specified by the -Count parameter. It supports pipeline input.

    The main design pattern of this command was abstracted from
    greymd(Yasuhiro, Yamada)'s "egzact".
    Here is the original copyright notice for "egzact":

        The MIT License Copyright (c) 2016 Yasuhiro, Yamada
        https://github.com/greymd/egzact/blob/master/LICENSE


.PARAMETER Count
    Specifies duplication count for each object. Must be >= 1.
    Default is 2.

.PARAMETER InputObject
    Object to be duplicated. Accepts pipeline input.

.INPUTS
    System.Object (from pipeline or -InputObject)

.OUTPUTS
    System.Object (duplicated objects)

.EXAMPLE
    PS C:\> "A B C D" | dupl 3
    A B C D
    A B C D
    A B C D

.EXAMPLE
    PS C:\> 1..5 | dupl 2
    1
    1
    2
    2
    3
    3
    4
    4
    5
    5

.EXAMPLE
    PS C:\> "Kuri-Manju" | dupl -Count 2 | dupl -Count 2 | dupl -Count 2 | dupl -Count 2 | dupl -Count 2 | dupl -Count 2

    # Duplicates "Kuri-Manju" 64 times.
#>
function dupl {
    [CmdletBinding()]
    [OutputType([System.Object])]
    param (
        [Parameter(Mandatory=$false, Position=0)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Count = 2,

        [Parameter(ValueFromPipeline=$true)]
        [object]$InputObject
    )

    begin {
        # No setup needed.
    }

    process {
        # Duplicate the current input object 'Count' times.
        for ($i = 0; $i -lt $Count; $i++) {
            Write-Output $_
        }
    }

    end {
        # No cleanup needed.
    }
}
