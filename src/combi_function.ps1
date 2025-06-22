<#
.SYNOPSIS
    combi - Generates combinations.

    Generates combinations of 'r' elements from a set of 'n' input elements.
    Maximum number of input columns (n) is 10.

    Usage:
        <input_string> | combi <r>

    Example:
        "A B C" | combi 2
        # Output:
        # A B
        # A C
        # B C

.DESCRIPTION
    The main design pattern of this command was abstracted from
    greymd(Yasuhiro, Yamada)'s "egzact".
    Here is the original copyright notice for "egzact":

        The MIT License Copyright (c) 2016 Yasuhiro, Yamada
        https://github.com/greymd/egzact/blob/master/LICENSE

.PARAMETER Delimiter
    Input/Output field separator. Alias: -fs
    Default value is space " ". This is used if -InputDelimiter or -OutputDelimiter are not specified.

.PARAMETER InputDelimiter
    Input field separator. Alias: -ifs
    Overrides -Delimiter for input splitting if specified.

.PARAMETER OutputDelimiter
    Output field separator. Alias: -ofs
    Overrides -Delimiter for output joining if specified.

.LINK
    perm, combi, dcombi

.EXAMPLE
    Write-Output "A B C" | combi 2
    # Output:
    # A B
    # A C
    # B C

    Write-Output "A B C" | perm 2
    # Output:
    # A B
    # A C
    # B A
    # B C
    # C A
    # C B

    Write-Output "A B C" | dcombi 2
    # Output:
    # A A
    # A B
    # A C
    # B A
    # B B
    # B C
    # C A
    # C B
    # C C

    # Equivalent to "combi 2" using dcombi
    Write-Output "A B C" | dcombi 2 | pawk -Pattern { $1 -lt $2 }
    # Output:
    # A B
    # A C
    # B C

#>
function combi {

    param (
        [Parameter(Mandatory=$False, Position=0)]
        [ValidateRange(1,10)]
        [Alias('n')]
        [int] $Num = 1, # Number of elements to choose (r from n). Max is 10.

        [Parameter(Mandatory=$False)]
        [Alias('fs')]
        [string] $Delimiter = ' ', # Default field separator.

        [Parameter(Mandatory=$False)]
        [Alias('ifs')]
        [string] $InputDelimiter, # Specific input field separator.

        [Parameter(Mandatory=$False)]
        [Alias('ofs')]
        [string] $OutputDelimiter, # Specific output field separator.

        [parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [string[]] $InputText # Input text from the pipeline.
    )

    begin {
        # Determine effective input and output delimiters based on parameter precedence.
        if ($InputDelimiter -and $OutputDelimiter) {
            [string] $iDelim = $InputDelimiter
            [string] $oDelim = $OutputDelimiter
        } elseif ($InputDelimiter) {
            [string] $iDelim = $InputDelimiter
            [string] $oDelim = $InputDelimiter # Use input delimiter for output if only input is specified.
        } elseif ($OutputDelimiter) {
            [string] $iDelim = $Delimiter # Use default delimiter for input if only output is specified.
            [string] $oDelim = $OutputDelimiter
        } else {
            [string] $iDelim = $Delimiter
            [string] $oDelim = $Delimiter
        }

        # Check if the input delimiter is empty, indicating character-by-character splitting.
        if ($iDelim -eq '') {
            [bool] $emptyDelimiterFlag = $True
        } else {
            [bool] $emptyDelimiterFlag = $False
        }

        # Create zero-padding string for number formatting.
        [string] $strZero = '0' * $Num
    }

    process {
        # Initialize variables for current pipeline object processing.
        [string] $writeLine = ''
        [string] $readLine = [string] $_

        # Split the input line into an array of strings (columns) or characters.
        [string[]] $splitReadLine
        if ($emptyDelimiterFlag) {
            $splitReadLine = $readLine.ToCharArray()
        } else {
            $splitReadLine = $readLine.Split($iDelim)
        }

        # Calculate total number of elements in the input and validate count.
        [int] $baseNum = $splitReadLine.Count
        if ($baseNum -gt 10) {
            Write-Error "The number of fields has exceeded 10." -ErrorAction Stop
        }

        # Calculate the total number of combinations (baseN permutations).
        [int] $combiTotalNum = [math]::Pow($baseNum, $Num)

        # Main logic for generating combinations.
        $hash = @{} # Used to store and filter unique combinations.
        for ($i = 0; $i -lt $combiTotalNum; $i++) {
            # Convert decimal index 'i' to a base-N string, representing element indices.
            [string] $baseNstr = ''
            [decimal] $base10Num = $i
            do {
                # Calculate quotient and remainder for base conversion.
                $div = ($base10Num - $base10Num % $baseNum) / $baseNum
                $mod = $base10Num % $baseNum
                # Prepend remainder to build the base-N string.
                [string] $baseNstr = [string]$mod + [string]$baseNstr
                $base10Num = $div
            } while ($base10Num -ge $baseNum)

            # Append the last digit if remaining after loop.
            if ($base10Num -ne 0) {
                $baseNstr = [string]$div + [string]$baseNstr
            }

            # Accumulate base-N strings (this part of the original script seems to have an issue;
            # it concatenates $writeLine with itself in a loop, resulting in a single long string).
            # It seems like it was intended to handle multiple lines of input in a different way,
            # but given 'process' block runs for each pipeline object, this accumulation
            # will only happen for a single input line, making it less clear.
            # However, preserving original logic as per instruction not to change code.
            if ($i -eq 0) {
                [string] $writeLine = [string] $baseNstr
            } else {
                [string] $writeLine = $writeLine + [string] $baseNstr
            }

            # Pad the base-N string with leading zeros to match $Num length.
            [string[]] $splitNum = ([decimal]$writeLine).ToString("$strZero") -split ''
            Write-Debug ([decimal]$writeLine).ToString("$strZero")

            # Check if each element is used exactly once (for permutations/combinations without repetition).
            # This logic filters out permutations and duplicates, keeping only true combinations.
            [int] $NumOfAllElements = $splitNum.Count - 2 # Exclude empty strings from split.
            [int] $NumOfInputElements = (([decimal]$writeLine).ToString("$strZero").GetEnumerator() | Sort-Object -Unique).Count

            if ($NumOfAllElements -ne $NumOfInputElements) {
                [string] $writeLine = '' # Reset for next iteration if not a valid combination.
                continue
            }

            # Check for and prevent duplicate combinations by sorting the indices and using a hash table.
            [string] $sortedKey = "e"
            [string] $sortedKey += @(([decimal]$writeLine).ToString("$strZero").GetEnumerator() | Sort-Object) -join ""

            if ($hash.ContainsKey($sortedKey)) {
                [string] $writeLine = '' # Reset for next iteration if already seen.
                continue
            } else {
                $hash.add($sortedKey, 0)
            }

            # Construct the output string using the elements from $splitReadLine based on the calculated indices.
            [string] $writeLine = [string]($splitReadLine[($splitNum[1])]) # Start with the first actual element.
            for ($k = 2; $k -lt $splitNum.Count - 1; $k++) {
                [string] $writeLine = $writeLine + $oDelim + [string]($splitReadLine[($splitNum[$k])])
            }
            Write-Output $writeLine
            [string] $writeLine = '' # Reset writeLine for the next combination.
        }
    }

    # The 'end' block is implicitly empty as there's no finalization logic needed.
}
