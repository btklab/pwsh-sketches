<#
.SYNOPSIS
    Sanitize-FileName - Replaces characters that are not suitable for Windows filenames.

.DESCRIPTION
    This function replaces characters that cannot be used in Windows filenames (e.g., \, /, :, *, ?, ", <, >, |) 
    in a given string or a string passed from the pipeline with a specified replacement character 
    (default is an underscore '_').

.PARAMETER FileName
    The filename(s) (string) to be sanitized. Accepts multiple values and pipeline input.

.PARAMETER Replacement
    Specifies the character to use for replacing invalid characters. The default is '_'.

.EXAMPLE
    PS C:\> Sanitize-FileName -FileName "My*File:Name?.txt"
    My_File_Name_.txt

    In this example, the invalid characters *, :, and ? are replaced with '_'.

.EXAMPLE
    PS C:\> "My<File>Name.txt" | Sanitize-FileName
    My_File_Name.txt

    In this example, the string passed via the pipeline is sanitized.

.EXAMPLE
    PS C:\> Sanitize-FileName "My/Invalid\Name.log" -Replacement "-"
    My-Invalid-Name.log

    In this example, a hyphen '-' is specified as the replacement character.

.EXAMPLE
    PS C:\> $fileList = "file:1.txt", "file*2.txt", "file/3.txt"
    PS C:\> $fileList | Sanitize-FileName
    file_1.txt
    file_2.txt
    file_3.txt

    In this example, an array of strings is passed via the pipeline, and each is sanitized.

.INPUTS
    System.String
    You can pipe filename strings to this function.

.OUTPUTS
    System.String
    Outputs the sanitized filename string.
#>
function Sanitize-FileName {
    [CmdletBinding()]
    param (
        # Specifies the filename to sanitize. Accepts input from the pipeline.
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 0)]
        [Alias('f')]
        [string[]]$FileName,

        # Specifies the character to replace invalid characters with.
        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [string]$Replace = '_'
    )

    begin {
        # Uses a .NET method to get an array of characters that are invalid in filenames as defined by the system.
        # This allows for robust, environment-independent processing.
        $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
        
        # Escapes the array of invalid characters to be safely used in a regular expression.
        $escapedInvalidChars = [regex]::Escape(-join $invalidChars)
        
        # Creates the regex pattern for replacement. e.g., "[\/\:\*\?\""\<\>\|]"
        $regexPattern = "[$escapedInvalidChars]"
    }

    process {
        # Processes each filename passed from the parameter or pipeline.
        foreach ($file in $FileName) {
            # Uses the -replace operator and the regex pattern to replace invalid characters with the replacement character.
            $sanitizedName = $file -replace $regexPattern, $Replace
            
            # Outputs the result.
            Write-Output $sanitizedName
        }
    }
}

