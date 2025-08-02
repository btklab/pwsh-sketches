<#
.SYNOPSIS
    Get-RelativePath - Generate the relative path of a non-existent file or directory.

.DESCRIPTION
    This function takes an absolute path and a base path and returns
    the relative path from the base to the target. It handles both
    files and directories.
    
    Note: The function supports both existing and non-existing paths.

.PARAMETER Path
    The destination file or directory path to compute the relative path to.
    Accepts pipeline input.

.PARAMETER RelativeTo
    The base file or directory path from which the relative path is computed.
    If not specified, the current location is used as the base.

.PARAMETER Parent
    If specified, the parent directory of the input path will be used
    as the target for relative path calculation.

.EXAMPLE
    PS C:\Users\User\Documents> Get-RelativePath -Path "C:\Users\User\Documents\Reports\2025\report.docx"

    .\Reports\2025\report.docx

    # Computes the relative path from the current directory to the target file.

.EXAMPLE
    PS C:\> Get-RelativePath -Path "C:\Data\Shared\image.png" -RelativeTo "C:\Data\Projects\ProjectA"

    ..\Shared\image.png

    # Computes the relative path from one project folder to a file in a shared folder,
    # even if the paths do not exist.

.EXAMPLE
    PS C:\> "C:\Windows\System32", "C:\Temp\non-existent-file.log" | Get-RelativePath -RelativeTo "C:\Windows"

    System32
    ..\Temp\non-existent-file.log

    # Processes multiple paths via pipeline input.

.EXAMPLE
    PS C:\> Get-RelativePath -Path "C:\Logs\server.log" -RelativeTo "C:\Projects\App1" -Parent

    ..\..\Logs

    # Computes the relative path from the base path to the parent directory of the target file.

.NOTES
    This function uses the [System.Uri] class in .NET to compute relative paths.
    Paths are first converted to absolute form using [System.IO.Path]::GetFullPath(),
    which does not require the file or directory to exist.

    The resulting absolute paths are then converted to Uri objects, and the
    MakeRelativeUri() method is used to compute the relative path.

.OUTPUTS
    System.String
    Returns a string representing the computed relative path.
#>
function Get-RelativePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$RelativeTo = ".",

        [Parameter(Mandatory = $false)]
        [switch]$Parent,

        [Parameter(Mandatory = $false)]
        [Alias('d')]
        [string]$Delimiter = '/'
        )

    process {
        try {
            # Convert input paths to absolute paths without checking existence
            [string]$resolvedPath = [System.IO.Path]::GetFullPath(
                [System.IO.Path]::Combine((Get-Location).Path, $Path)
            )
            #$resolvedPath.GetType()

            if ($Parent) {
                [string]$resolvedPath = [System.IO.Path]::GetDirectoryName($resolvedPath)
            }

            $resolvedBase = [System.IO.Path]::GetFullPath(
                [System.IO.Path]::Combine((Get-Location).Path, $RelativeTo)
            )

            # Ensure base path ends with directory separator
            if (-not $resolvedBase.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
                [string]$resolvedBase += [System.IO.Path]::DirectorySeparatorChar
            }

            # Create Uri objects and calculate relative path
            $baseUri = [System.Uri]$resolvedBase
            $targetUri = [System.Uri]$resolvedPath
            $relativeUri = $baseUri.MakeRelativeUri($targetUri)

            # Decode and normalize the result
            [string] $relativePath = [System.Uri]::UnescapeDataString($relativeUri.ToString())
            [string] $relativePath = $relativePath.Replace('/', $Delimiter)

            return $relativePath
        }
        catch {
            Write-Error "Failed to compute relative path. From: '$RelativeTo', To: '$Path'. Error: $($_.Exception.Message)"
        }
    }
}
