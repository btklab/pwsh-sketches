<#
.SYNOPSIS
    Get-FullPath - Generate the absolute path of a non-existent file or directory.

.DESCRIPTION
    This function takes a string representing a file or directory
    path and converts it into a fully qualified, absolute path.
    It handles both relative and absolute input paths correctly.

    Note: The function supports both existing and non-existing paths.

.PARAMETER Path
    The file or directory path to convert. This can be a relative path (e.g., ".\reports\report.txt")
    or an absolute path (e.g., "C:\data\archive.zip"). This parameter accepts pipeline input.

.PARAMETER Parent
    If specified, the function returns the absolute path of the parent directory of the given path.

.EXAMPLE
    PS C:\Users\Anne> Get-FullPath -Path "Documents\project.plan"

    C:\Users\Anne\Documents\project.plan

    # Converts a relative path to its absolute form.

.EXAMPLE
    PS C:\> ".\temp\log.txt", "D:\backups\config.json" | Get-FullPath

    C:\temp\log.txt
    D:\backups\config.json

    # Converts multiple paths from the pipeline.

.EXAMPLE
    PS C:\Users\Anne> Get-FullPath -Path "Documents\project.plan" -Parent

    C:\Users\Anne\Documents

    # Returns the parent directory's absolute path.

.NOTES
    Author: Your Name
    Date:   2025-07-27

    This function uses [System.IO.Path]::GetFullPath() to convert the path
    without checking the file system. This avoids errors from non-existent paths
    and differs from Resolve-Path, which fails if the target does not exist.

.OUTPUTS
    System.String
    Returns a fully qualified path string.
#>
function Get-FullPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [switch]$Parent,

        [Parameter(Mandatory = $false)]
        [Alias('d')]
        [string]$Delimiter = '/'
    )

    process {
        try {
            if ([string]::IsNullOrWhiteSpace($Path)) {
                return
            }

            # Resolve the path to absolute
            if ([System.IO.Path]::IsPathRooted($Path)) {
                $fullPath = [System.IO.Path]::GetFullPath($Path)
            } else {
                $currentDirectory = (Get-Location).Path
                $fullPath = [System.IO.Path]::GetFullPath(
                    [System.IO.Path]::Combine($currentDirectory, $Path)
                )
            }

            # If -Parent is specified, get the parent directory
            if ($Parent) {
                $fullPath = [System.IO.Path]::GetDirectoryName($fullPath)
            }
            $fullPath = $fullPath.Replace('\', $Delimiter)

            return $fullPath
        }
        catch {
            Write-Error "Failed to convert the path '$Path'. Error: $($_.Exception.Message)"
        }
    }
}
