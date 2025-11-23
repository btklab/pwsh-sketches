<#
.SYNOPSIS
    Build-CSharpAssembly - Compiles a .cs into a .dll

    Compiles a C# source file (.cs) into a compiled library
     (.dll) in the same directory.

.DESCRIPTION
    This function takes a path to a C# source file, compiles it using the .NET framework 
    available to the current PowerShell session, and outputs a DLL file.
    
    The output DLL will have the same base name as the source file 
    (e.g., 'MyClass.cs' -> 'MyClass.dll') and will be placed in the same folder.

    Design Principles (Readable Code):
    - Clear variable naming.
    - Explicit error handling.
    - Informative user feedback.

.PARAMETER Path
    The path to the C# source file (*.cs). 
    Accepts relative or absolute paths.

.PARAMETER ReferencedAssemblies
    An optional list of assembly names or paths required for compilation 
    (e.g., 'System.Windows.Forms', 'System.Drawing').
    Basic system assemblies are included by default.

.EXAMPLE
    # Example 1: Basic compilation
    Build-CSharpAssembly -Path ".\Utils\StringHelper.cs"
    
    # Result: Creates ".\Utils\StringHelper.dll"

.EXAMPLE
    # Example 2: Compiling with dependencies
    Build-CSharpAssembly -Path ".\GUI\MyForm.cs" -ReferencedAssemblies "System.Windows.Forms", "System.Drawing"

.NOTES
    Limitations:
    1. File Locking: Once a DLL is loaded into a PowerShell session (via Add-Type or using), 
       it cannot be overwritten until the session is closed. If you need to re-compile 
       frequently, you must restart PowerShell.
    2. C# Version: The compiler version depends on the PowerShell version. 
       (PowerShell 5.1 uses .NET Framework 4.x, PowerShell 7+ uses .NET Core/.NET 5+).
#>
function Build-CSharpAssembly {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string[]]$ReferencedAssemblies = @()
    )

    process {
        # 1. Resolve Input Paths
        # Convert relative paths (e.g., ".\file.cs") to absolute paths to prevent errors.
        try {
            $sourceItem = Get-Item -Path $Path -ErrorAction Stop
            $sourceFilePath = $sourceItem.FullName
        }
        catch {
            Write-Error "Error: Could not resolve path '$Path'."
            return
        }

        # Ensure the file is a C# file
        if ($sourceItem.Extension -ne ".cs") {
            Write-Warning "The file '$($sourceItem.Name)' does not have a .cs extension. Proceeding anyway..."
        }

        # 2. Determine Output Path
        # The DLL is created in the exact same directory as the source file.
        # We use System.IO.Path to safely swap the extension.
        $outputDllPath = [System.IO.Path]::ChangeExtension($sourceFilePath, ".dll")

        Write-Host "Compiling: $sourceFilePath" -ForegroundColor Cyan
        Write-Host "Target:    $outputDllPath" -ForegroundColor DarkGray

        # 3. Compile
        try {
            # Add-Type is the cleanest way to invoke the C# compiler from PowerShell.
            # -OutputType Library ensures we get a .dll, not an .exe.
            Add-Type -Path $sourceFilePath `
                     -OutputAssembly $outputDllPath `
                     -OutputType Library `
                     -ReferencedAssemblies $ReferencedAssemblies `
                     -ErrorAction Stop

            Write-Host "Build Successful!" -ForegroundColor Green
            Write-Host "Created: $outputDllPath" -ForegroundColor Green
            Get-Item -LiteralPath $outputDllPath
        }
        catch {
            # 4. Error Handling
            # If compilation fails (syntax errors, missing references, or file locking),
            # we provide a clean error message.
            Write-Error "Compilation Failed."
            Write-Error $_.Exception.Message
            
            # Tip for the user regarding file locking (common issue)
            if ($_.Exception.Message -match "process cannot access the file") {
                Write-Warning "The DLL might be in use by the current PowerShell session. Restart PowerShell to rebuild."
            }
        }
    }
}
