<#
.Synopsis
    Convert-Image (Alias: ConvImage) - Image rotation, flipping, scaling

    Image format conversion is automatically recognized
    form the extension of the filenames.

    ConvImage -i <file> -o <file> [-notOverWrite]
    ConvImage -i <file> -o <file> -resize <height>x<width> [-notOverWrite]
    ConvImage -i <file> -o <file> -rotate <degrees> [-flip] [-flop] ] [-notOverWrite]

    Inspired by:

    Get-Draw.ps1 - miyamiya/mypss: My PowerShell scripts - GitHub
        - https://github.com/miyamiya/mypss
        - License: The MIT License (MIT): Copyright (c) 2013 miyamiya
    ImageMagick (command)
        - https://imagemagick.org/index.php

.Parameter inputFile
    Input image file.

.Parameter outputFile
    Output image file
    
    Convert to the specified format from file extension.
    Extensions that can be used:
    
    jpg,png,bmp,emf,gif,tiff,wmf,exif,guid,icon,...

.Parameter Exif
    Inherit image file properties such as Exif information
    as much as possible.

    Supported only when resizing image.

.Parameter ExifOrientationOnly
    Inherit only the properties (Exif information) of the
    image orientation (up, down, left and right)

    Supported only when resizing image.

.Parameter resize
    Specify the output image size in <height>x<width>
    e.g. 200x100 or 200

    Aspect ratio is preserved. if size is specified by
    <height>x<width>, the aspect ratio is maintained
    and resized based on the longest side.

    e.g.
    100x100 : Pixel specification
    100     : Pixel specification (height only)
    50%     : Ratio specification (height only)

.Parameter rotate
    Specify rotation angle.

.Parameter flip
    flip top/bottom

.Parameter flop
    Invert left/right

.Parameter notOverWrite
    If the output file already exists,
    do not overwrite it.

.EXAMPLE
    ConvImage before.jpg after.png

    Description
    ========================
    Easiest example.
    Convert format "before.jpg" to "after.png".

.EXAMPLE
    ConvImage before.jpg after.png -resize 500x500

    Description
    ========================
    The simplest example #2.
    Convert format "before.jpg" to  "after.png", and
    resize the image to fit in the 500x500 px.
    Acpect ratio is preserved.

.EXAMPLE
    ConvImage -i before.jpg -o after.png -resize 100x100

    Description
    ========================
    Option names are described without omission.(but use alias)
    The results is the same as above example.

.EXAMPLE
    ConvImage -i before.jpg -o after.png -resize 100x100 -notOverWrite

    Description
    ========================
    Convert format ".jpg" to ".png",
    Resize to 100x100 px with keeoing the aspect ratio,
    do not overwrite if "after.png" already exist.

.EXAMPLE
    ConvImage before.jpg after.png -resize 10%

    Description
    ========================
    Convert format ".jpg" to ".png",
    Scale down to 10% (1/10) of the pixels in height and width.
    Aspect ratio is preserved.

.EXAMPLE
    ConvImage before.jpg after.png -resize 100

    Description
    ========================
    Convert format ".jpg" to ".png",
    Resize 1o 100px in height (vertical),
    Aspect ratio is preserved.

.EXAMPLE
    ConvImage before.jpg after.png -rotate 90

    Description
    ========================
    Convert format ".jpg" to ".png",
    Rotate 90 degrees.

.EXAMPLE
    ConvImage before.jpg after.png -rotate 90 -flip

    Description
    ========================
    Convert format ".jpg" to ".png",
    Rotate 90 degrees and
    Flip upside down.

.EXAMPLE
    ConvImage before.jpg after.png -rotate 90 -flop
    
    Description
    ========================
    Convert format ".jpg" to ".png",
    Rotate 90 degrees,
    Flip left and right

#>
function Convert-Image {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $True, Position = 0)]
        [Alias('i')]
        [string]$inputFile,

        [parameter(Mandatory = $True, Position = 1)]
        [Alias('o')]
        [string]$outputFile,

        [parameter(Mandatory = $False)]
        [string]$resize = "None",

        [parameter(Mandatory = $False)]
        [ValidateSet("90", "180", "270")]
        [string]$rotate = "None",

        [parameter(Mandatory = $False)]
        [switch]$flip,

        [parameter(Mandatory = $False)]
        [switch]$flop,

        [parameter(Mandatory = $False)]
        [switch]$Exif,

        [parameter(Mandatory = $False)]
        [switch]$ExifOrientationOnly,

        [parameter(Mandatory = $False)]
        [switch]$notOverWrite
    )

    #region Helper Functions
    # These functions encapsulate specific logic to make the main script body more readable.

    # Converts a file extension string to a System.Drawing.Imaging.ImageFormat object.
    function Get-ImageFormatFromExtension($extension) {
        # Using a switch statement is cleaner than a long chain of if-statements.
        switch ($extension.ToLower()) {
            'jpg'  { return [System.Drawing.Imaging.ImageFormat]::Jpeg }
            'jpeg' { return [System.Drawing.Imaging.ImageFormat]::Jpeg }
            'png'  { return [System.Drawing.Imaging.ImageFormat]::Png }
            'bmp'  { return [System.Drawing.Imaging.ImageFormat]::Bmp }
            'emf'  { return [System.Drawing.Imaging.ImageFormat]::Emf }
            'gif'  { return [System.Drawing.Imaging.ImageFormat]::Gif }
            'tiff' { return [System.Drawing.Imaging.ImageFormat]::Tiff }
            'wmf'  { return [System.Drawing.Imaging.ImageFormat]::Wmf }
            'exif' { return [System.Drawing.Imaging.ImageFormat]::Exif }
            'guid' { return [System.Drawing.Imaging.ImageFormat]::Guid }
            'icon' { return [System.Drawing.Imaging.ImageFormat]::Icon }
            default {
                # If the extension is unsupported, throw an error.
                Write-Error "Unsupported output file extension: $extension" -ErrorAction Stop
            }
        }
    }

    # Resolves, validates, and standardizes input and output file paths.
    function Resolve-AndValidatePaths($inputFile, $outputFile, $notOverWrite) {
        $currentDirectory = (Convert-Path .)

        # Ensure paths are absolute for reliability.
        $resolvedInputPath = if (-not [System.IO.Path]::IsPathRooted($inputFile)) {
            Join-Path -Path $currentDirectory -ChildPath $inputFile
        }
        else {
            $inputFile
        }

        $resolvedOutputPath = if (-not [System.IO.Path]::IsPathRooted($outputFile)) {
            Join-Path -Path $currentDirectory -ChildPath $outputFile
        }
        else {
            $outputFile
        }

        # --- Validation Checks (Guard Clauses) ---
        # Using guard clauses to exit early makes the main logic path clearer.
        if (-not (Test-Path $resolvedInputPath)) {
            Write-Error "Input file does not exist: $resolvedInputPath" -ErrorAction Stop
        }

        if ($notOverWrite -and (Test-Path $resolvedOutputPath)) {
            Write-Error "Output file already exists and -notOverWrite was specified: $resolvedOutputPath" -ErrorAction Stop
        }

        if ($resolvedInputPath -eq $resolvedOutputPath) {
            Write-Error "Input and output files cannot be the same." -ErrorAction Stop
        }

        $outputExtension = [System.IO.Path]::GetExtension($resolvedOutputPath).TrimStart('.')
        $outputImageFormat = Get-ImageFormatFromExtension $outputExtension

        # Return a custom object containing the validated paths and format.
        # This is clearer than returning an array or modifying variables in a higher scope.
        return [PSCustomObject]@{
            Input      = $resolvedInputPath
            Output     = $resolvedOutputPath
            Format     = $outputImageFormat
        }
    }

    # Calculates the new dimensions for resizing while preserving the aspect ratio.
    function Get-ResizedDimensions($originalImage, $resizeString) {
        [bool]$isPercentage = $resizeString.Contains('%')
        [string]$resizeValue = $resizeString.Replace('%', '')

        $originalHeight = $originalImage.Height
        $originalWidth = $originalImage.Width
        $newHeight = 0
        $newWidth = 0
        $ratio = 1.0

        if ($resizeValue -match 'x') {
            # --- Case: Size specified as <height>x<width> (e.g., "800x600") ---
            $parts = $resizeValue -split 'x'
            if ($parts.Count -ne 2) { Write-Error "Invalid -resize format. Use <height>x<width>." -ErrorAction Stop }
            $targetHeight = [int]$parts[0]
            $targetWidth = [int]$parts[1]

            # To preserve aspect ratio, we calculate the scaling ratio for both height and width
            # and use the smaller of the two. This ensures the image fits within the target box.
            $heightRatio = $targetHeight / $originalHeight
            $widthRatio = $targetWidth / $originalWidth
            $ratio = [System.Math]::Min($heightRatio, $widthRatio)
        }
        else {
            # --- Case: Size specified as a single number (height) or percentage ---
            $targetSize = [double]$resizeValue
            $ratio = if ($isPercentage) {
                $targetSize / 100.0
            }
            else {
                # If a single pixel value is given, it's treated as the target height.
                $targetSize / $originalHeight
            }
        }

        $newHeight = [int]($originalHeight * $ratio)
        $newWidth = [int]($originalWidth * $ratio)

        return [PSCustomObject]@{
            Height = $newHeight
            Width  = $newWidth
        }
    }

    # Transfers EXIF properties from a source image to a destination image.
    function Copy-ExifData($sourceImage, $destinationImage, $orientationOnly) {
        # EXIF Orientation Tag ID is 0x0112 (274). This tag specifies the visual orientation of the image.
        # See: https://www.exiv2.org/tags.html
        $EXIF_ORIENTATION_TAG_ID = 0x0112

        foreach ($propertyItem in $sourceImage.PropertyItems) {
            if ($orientationOnly) {
                # Copy only the orientation property.
                if ($propertyItem.Id -eq $EXIF_ORIENTATION_TAG_ID) {
                    $destinationImage.SetPropertyItem($propertyItem)
                }
            }
            else {
                # Copy all properties.
                $destinationImage.SetPropertyItem($propertyItem)
            }
        }
    }

    #endregion Helper Functions


    # ==============================================================================
    #  MAIN SCRIPT LOGIC
    # ==============================================================================

    # --- Parameter Validation ---
    # Operations are mutually exclusive. An image cannot be resized and rotated in the same command.
    if (($resize -ne 'None') -and ($rotate -ne 'None' -or $flip -or $flop)) {
        Write-Error "The -resize and -rotate/-flip/-flop parameters cannot be used at the same time." -ErrorAction Stop
    }

    # --- Path Resolution ---
    # All path-related checks are handled by the helper function.
    $paths = Resolve-AndValidatePaths $inputFile $outputFile $notOverWrite

    # --- Image Processing ---
    # Load the .NET assembly required for image manipulation.
    Add-Type -AssemblyName System.Drawing

    $sourceImage = $null
    try {
        # Load the source image. This is the only object we need to manage in the finally block.
        $sourceImage = [System.Drawing.Bitmap]::new($paths.Input)

        # Determine which action to take based on parameters.
        if ($resize -ne 'None') {
            # --- Action: Resize Image ---
            $dimensions = Get-ResizedDimensions -originalImage $sourceImage -resizeString $resize
            
            # Create a new bitmap canvas with the calculated new dimensions.
            $resizedImage = [System.Drawing.Bitmap]::new($dimensions.Width, $dimensions.Height)
            $graphicsContext = [System.Drawing.Graphics]::FromImage($resizedImage)
            
            # Draw the original image onto the new canvas, effectively resizing it.
            $rect = [System.Drawing.Rectangle]::new(0, 0, $dimensions.Width, $dimensions.Height)
            $graphicsContext.DrawImage($sourceImage, $rect)

            # Copy EXIF data if requested.
            if ($Exif -or $ExifOrientationOnly) {
                Copy-ExifData -sourceImage $sourceImage -destinationImage $resizedImage -orientationOnly $ExifOrientationOnly
            }

            # Save the newly created image.
            $resizedImage.Save($paths.Output, $paths.Format)

            # Clean up resources specific to this block.
            $graphicsContext.Dispose()
            $resizedImage.Dispose()
        }
        else {
            # --- Action: Rotate/Flip or Just Convert Format ---
            if ($rotate -ne 'None' -or $flip -or $flop) {
                # The RotateFlip method modifies the image in-place.
                # First, determine the correct RotateFlipType enum value.
                # This is more robust than constructing strings.
                $rotateFlipMap = @{
                    "RotateNoneFlipNone" = [System.Drawing.RotateFlipType]::RotateNoneFlipNone
                    "Rotate90FlipNone"   = [System.Drawing.RotateFlipType]::Rotate90FlipNone
                    "Rotate180FlipNone"  = [System.Drawing.RotateFlipType]::Rotate180FlipNone
                    "Rotate270FlipNone"  = [System.Drawing.RotateFlipType]::Rotate270FlipNone
                    "RotateNoneFlipX"    = [System.Drawing.RotateFlipType]::RotateNoneFlipX
                    "Rotate90FlipX"      = [System.Drawing.RotateFlipType]::Rotate90FlipX
                    "Rotate180FlipX"     = [System.Drawing.RotateFlipType]::Rotate180FlipX
                    "Rotate270FlipX"     = [System.Drawing.RotateFlipType]::Rotate270FlipX
                    "RotateNoneFlipY"    = [System.Drawing.RotateFlipType]::RotateNoneFlipY
                    "Rotate90FlipY"      = [System.Drawing.RotateFlipType]::Rotate90FlipY
                    "Rotate180FlipY"     = [System.Drawing.RotateFlipType]::Rotate180FlipY
                    "Rotate270FlipY"     = [System.Drawing.RotateFlipType]::Rotate270FlipY
                    "RotateNoneFlipXY"   = [System.Drawing.RotateFlipType]::RotateNoneFlipXY
                    "Rotate90FlipXY"     = [System.Drawing.RotateFlipType]::Rotate90FlipXY
                    "Rotate180FlipXY"    = [System.Drawing.RotateFlipType]::Rotate180FlipXY
                    "Rotate270FlipXY"    = [System.Drawing.RotateFlipType]::Rotate270FlipXY
                }
                $rotation = "Rotate" + $rotate
                $flipType = if ($flip -and $flop) { "FlipXY" } elseif ($flip) { "FlipY" } elseif ($flop) { "FlipX" } else { "FlipNone" }
                $rotateFlipKey = $rotation + $flipType
                
                $sourceImage.RotateFlip($rotateFlipMap[$rotateFlipKey])
            }
            # Save the (possibly modified) image to the output path.
            # This branch handles rotation/flipping as well as simple format conversion.
            $sourceImage.Save($paths.Output, $paths.Format)
        }
    }
    catch {
        # If any error occurs, pass it up to the caller.
        Write-Error $_
    }
    finally {
        # --- Resource Cleanup ---
        # This block ALWAYS runs, ensuring we don't leave file handles open.
        # This is critical for script stability and preventing locked files.
        if ($null -ne $sourceImage) {
            $sourceImage.Dispose()
        }
    }
}

# set alias
[String] $tmpAliasName = "ConvImage"
[String] $tmpCmdName   = "Convert-Image"
[String] $tmpCmdPath = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath $($MyInvocation.MyCommand.Name) `
    | Resolve-Path -Relative
if ( $IsWindows ){ $tmpCmdPath = $tmpCmdPath.Replace('\' ,'/') }
# is alias already exists?
if ((Get-Command -Name $tmpAliasName -ErrorAction SilentlyContinue).Count -gt 0){
    try {
        if ( (Get-Command -Name $tmpAliasName).CommandType -eq "Alias" ){
            if ( (Get-Command -Name $tmpAliasName).ReferencedCommand.Name -eq $tmpCmdName ){
                Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
                    | ForEach-Object{
                        Write-Host "$($_.DisplayName)" -ForegroundColor Green
                    }
            } else {
                throw
            }
        } elseif ( "$((Get-Command -Name $tmpAliasName).Name)" -match '\.exe$') {
            Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
                | ForEach-Object{
                    Write-Host "$($_.DisplayName)" -ForegroundColor Green
                }
        } else {
            throw
        }
    } catch {
        Write-Error "Alias ""$tmpAliasName ($((Get-Command -Name $tmpAliasName).ReferencedCommand.Name))"" is already exists. Change alias needed. Please edit the script at the end of the file: ""$tmpCmdPath""" -ErrorAction Stop
    } finally {
        Remove-Variable -Name "tmpAliasName" -Force
        Remove-Variable -Name "tmpCmdName" -Force
    }
} else {
    Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
        | ForEach-Object {
            Write-Host "$($_.DisplayName)" -ForegroundColor Green
        }
    Remove-Variable -Name "tmpAliasName" -Force
    Remove-Variable -Name "tmpCmdName" -Force
}
