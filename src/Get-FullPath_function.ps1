<#
.SYNOPSIS
    Get-FullPath - Converts a file path to its absolute path.

.DESCRIPTION
    This function takes a string representing a file or directory path and converts it into a
    fully qualified, absolute path. It correctly handles both relative and absolute input paths.

    A key feature of this function is that it does not require the path to exist on the file
    system, making it suitable for generating paths for files that have not yet been created.

.PARAMETER Path
    The file or directory path to convert. This can be a relative path (e.g., ".\reports\report.txt")
    or an absolute path (e.g., "C:\data\archive.zip"). This parameter accepts pipeline input.

.EXAMPLE
    PS C:\Users\Anne> ConvertTo-FullPath -Path "Documents\project.plan"

    C:\Users\Anne\Documents\project.plan

    # This example shows how a relative path is converted to a full path
    # based on the user's current location.

.EXAMPLE
    PS C:\> ".\temp\log.txt", "D:\backups\config.json" | ConvertTo-FullPath

    C:\temp\log.txt
    D:\backups\config.json

    # This example demonstrates using the pipeline to resolve multiple paths.
    # It correctly converts both a relative path and an absolute path, even if they do not exist.

.NOTES
    Author: Your Name
    Date:   2025-07-17

    This function uses [System.IO.Path]::GetFullPath() from the .NET Framework.
    This method was chosen specifically because it resolves a path string without accessing the
    file system to verify its existence. This is the key difference from PowerShell's native
    `Resolve-Path` cmdlet, which would throw an error if the path does not point to an existing item.

.OUTPUTS
    System.String
#>
function Get-FullPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [string]$Path
    )

    process {
        try {
            # This is the core logic of the function.
            # We use the .NET GetFullPath() method because, unlike PowerShell's Resolve-Path,
            # it purely operates on the path string. It doesn't touch the file system,
            # so it won't fail if the path doesn't exist yet. This makes it ideal
            # for pre-calculating paths for new files or directories.
            if ([string]::IsNullOrWhiteSpace($Path)) {
                return
            }
            [System.IO.Path]::IsPathRooted($Path)
            if ( [System.IO.Path]::IsPathRooted($Path)) {
                [string] $fullPath = [System.IO.Path]::GetFullPath($Path)
            } else {
                [string] $currentDirectory = (Convert-Path -Path .)
                [string] $joinedPath = Join-Path $currentDirectory $Path
                [string] $fullPath = [System.IO.Path]::GetFullPath($joinedPath)
            }
            return $fullPath
        }
        catch {
            # This catch block handles rare cases where the input path string itself is
            # invalid (e.g., contains illegal characters), not that the path doesn't exist.
            #Write-Error "Failed to convert the path '$Path'. The path may contain invalid characters."
        }
    }
}

