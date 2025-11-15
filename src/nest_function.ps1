<#
.SYNOPSIS
    nest - Nests fields from an input string using a specified pattern.
    
    By default, the leftmost field is placed in the deepest nested level.

.DESCRIPTION
    This cmdlet takes an input string (typically from the pipeline) and a
    pattern string. The pattern string must contain a '*' character, which
    acts as a placeholder for the input fields. The cmdlet will recursively
    nest the fields according to the pattern.

    You can specify custom delimiters for both parsing the input string
    and for separating the nested components in the output.

    The main design pattern of this command was abstracted from
    greymd(Yasuhiro, Yamada)'s "egzact".
    Here is the original copyright notice for "egzact":

        The MIT License Copyright (c) 2016 Yasuhiro, Yamada
        https://github.com/greymd/egzact/blob/master/LICENSE

.PARAMETER Pattern
    The pattern string to use for nesting. This string must contain exactly
    one '*' character, which will be replaced by the nested fields.
    Example: '(*)', '[<*>]', 'Before * After'

.PARAMETER Reverse
    When this switch is present, the nesting order is reversed.
    The rightmost field of the input string will be placed in the
    deepest nested level.

.PARAMETER InputDelimiter
    Specifies the delimiter used to split the input string into individual fields.
    If not specified, a single space character (' ') is used.
    This parameter can be used independently or in conjunction with OutputDelimiter.

.PARAMETER OutputDelimiter
    Specifies the delimiter used to separate nested components in the output string.
    If only InputDelimiter is specified, InputDelimiter's value will also be used
    for output. If neither is specified, a single space character (' ') is used.

.INPUTS
    System.String
        Accepts strings from the pipeline, where each string represents a line
        of fields to be nested.

.OUTPUTS
    System.String
        The formatted, nested string.

.EXAMPLE
    # Default behavior: Leftmost field is deepest, space delimiter
    PS C:\> "aaa bbb ccc" | nest -Pattern '( * )'
    ( ( ( aaa ) bbb ) ccc )

.EXAMPLE
    # Reverse behavior: Rightmost field is deepest, space delimiter
    PS C:\> "aaa bbb ccc" | nest -Pattern '( * )' -Reverse
    ( aaa ( bbb ( ccc ) ) )

.EXAMPLE
    # Using a different pattern
    PS C:\> "apple banana cherry" | nest -Pattern '[*] is a fruit.'
    [[[apple is a fruit.] is a fruit.] banana is a fruit.] cherry is a fruit.


.EXAMPLE
    # Using a custom output delimiter (hyphen)
    PS C:\> "one two three" | nest -Pattern '[*]' -OutputDelimiter '-'
    [[[one]-two]-three]

#>
function nest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [Alias('p')]
        [string]$Pattern,

        [Parameter(Mandatory=$false)]
        [Alias('r')]
        [switch]$Reverse,

        [Parameter(Mandatory=$false)]
        [Alias('fs')]
        [string]$InputDelimiter = ' ',

        [Parameter(Mandatory=$false)]
        [Alias('ofs')]
        [string]$OutputDelimiter = ' ',

        [parameter( Mandatory=$False, ValueFromPipeline=$True )]
        [string[]] $InputObject
    )

    begin {
        # Validate the pattern: must contain exactly one '*' and not at the ends.
        if ($Pattern -notmatch '\*') {
            throw (New-Object System.Management.Automation.RuntimeException "The -Pattern parameter must contain a '*' placeholder.")
        }
        if (($Pattern -split '\*').Length -ne 2) {
            throw (New-Object System.Management.Automation.RuntimeException "The -Pattern parameter must contain exactly one '*' placeholder.")
        }
        if ($Pattern.StartsWith('*') -or $Pattern.EndsWith('*')) {
            throw (New-Object System.Management.Automation.RuntimeException "The '*' placeholder in -Pattern cannot be at the beginning or end of the string.")
        }

        # Split the pattern into prefix and suffix based on the '*' placeholder.
        $splitPattern = $Pattern -split '\*'
        $PatternPrefix = $splitPattern[0]
        $PatternSuffix = $splitPattern[1]

        # Determine the effective input and output delimiters based on provided parameters.
        if ($PSBoundParameters.ContainsKey('InputDelimiter') -and $PSBoundParameters.ContainsKey('OutputDelimiter')) {
            # Both delimiters are explicitly provided
            $iDelim = $InputDelimiter
            $oDelim = $OutputDelimiter
        } elseif ($PSBoundParameters.ContainsKey('InputDelimiter')) {
            # Only InputDelimiter is provided, use it for both input and output
            $iDelim = $InputDelimiter
            $oDelim = $InputDelimiter
        } elseif ($PSBoundParameters.ContainsKey('OutputDelimiter')) {
            # Only OutputDelimiter is provided, use default space for input and custom for output
            $iDelim = ' '
            $oDelim = $OutputDelimiter
        } else {
            # Neither is provided, use default space for both
            $iDelim = ' '
            $oDelim = ' '
        }
    }

    process {
        [string]$inputString = $_

        # Clean the input string:
        # 1. Trim leading and trailing whitespace.
        # 2. Normalize multiple internal spaces to a single space if default delimiter is used.
        #    If a custom input delimiter is used, we only trim and let the split handle it.
        $cleanedInput = $inputString.Trim()
        if ($iDelim -eq ' ') {
            $cleanedInput = $cleanedInput -replace '\s+', ' '
        }

        # Split the cleaned input string into individual fields using the determined input delimiter.
        # Filter out empty strings that might result from splitting multiple delimiters next to each other.
        [string[]] $fields = $cleanedInput -split $iDelim | Where-Object { $_ -ne '' }

        if ($fields.Count -eq 0) {
            # If there are no fields after cleaning, output an empty string.
            Write-Output ""
            return
        }

        $result = ""

        if ($Reverse) {
            # Nesting from right to left (rightmost field is deepest)
            # Start with the deepest (rightmost) field
            $result = $PatternPrefix + $fields[$fields.Count - 1] + $PatternSuffix

            # Iterate backwards from the second-to-last field to the first.
            for ($i = $fields.Count - 2; $i -ge 0; $i--) {
                # Construct the new nested string: prefix + current field + output delimiter + previous result + suffix
                $result = $PatternPrefix + $fields[$i] + $oDelim + $result + $PatternSuffix
            }
        } else {
            # Default nesting from left to right (leftmost field is deepest)
            # Start with the deepest (leftmost) field
            $result = $PatternPrefix + $fields[0] + $PatternSuffix

            # Iterate forwards from the second field to the last.
            for ($i = 1; $i -lt $fields.Count; $i++) {
                # Construct the new nested string: prefix + previous result + output delimiter + current field + suffix
                $result = $PatternPrefix + $result + $oDelim + $fields[$i] + $PatternSuffix
            }
        }

        # Output the final nested string.
        Write-Output $result
    }

    end {
        # No specific cleanup needed in the end block for this function.
    }
}
