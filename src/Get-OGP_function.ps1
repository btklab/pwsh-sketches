<#
.SYNOPSIS
    Get-OGP (Alias:ml) - Fetches Open Graph data and formats it as a link.

.DESCRIPTION
    This function fetches Open Graph Protocol (OGP) and other metadata
    (like title, description, image) from a given URI.

    It can process multiple URIs provided as arguments, through the
    pipeline, or from the clipboard. If no URI is provided, it
    attempts to read URIs from the clipboard (one URI per line).

    **Amazon.co.jp URI Handling:**
    
    To comply with terms of service and avoid scraping, URIs matching
    'https://www.amazon.co.jp/' are *not* scraped. Instead, the URI is
    normalized (e.g., to a clean /dp/ASIN format) and output directly
    with an empty title and description.

    For all other sites, the function primarily looks for:
      <meta property="og:title" content="...">
      <meta property="og:url" content="...">
      <meta property="og:image" content="...">
      <meta property="og:description" content="...">
      <link rel="canonical" href="...">
      <title>...</title>

    Title Priority (non-Amazon sites):
      1. <meta property="og:title"... />
      2. <title>...</title>

    Description Priority (non-Amazon sites):
      1. <meta property="og:description"... />
      2. <meta name="description"... />

    URI Priority (when -Canonical is used on non-Amazon sites):
      1. <link rel="canonical" href="...">
      2. <meta property="og:url"... />
      3. The original input URI

.NOTES
    Title:      Get-OGP
    Author:     btklab
    Created:    2025-11-24
    
    --- Acknowledgements / License Info ---

    This script is inspired by and partially ported from "goark/ml".
    
    Original Project: https://github.com/goark/ml
    Original Author:  goark
    Original License: Apache License 2.0
    
    http://www.apache.org/licenses/LICENSE-2.0


.PARAMETER Uri
    The URI(s) to retrieve OGP data from. Accepts multiple values
    and pipeline input. If omitted, the function reads from the clipboard.

.PARAMETER Card
    Outputs the OGP data as a simple, self-contained HTML "blog card"
    link, suitable for embedding. (Ignored for Amazon.co.jp URIs).

.PARAMETER Markdown
    Outputs the link in Markdown format: [title](uri)

.PARAMETER Dokuwiki
    Outputs the link in DokuWiki format: [[uri|title]]

.PARAMETER Id
    Used with -Markdown to create a reference-style link.
    Example:
      [title][key]
      [key]: <uri>

    If -Id is provided with an empty string (-Id ""):
      [title][]
      [title]: <uri>

.PARAMETER Html
    Outputs the link as a standard HTML anchor tag: <a href="uri">title</a>

.PARAMETER Clip
    Sends the output directly to the clipboard instead of to the console.

.PARAMETER DownloadMetaImage
    Downloads the 'og:image' to the "~/Downloads" directory.
    (Ignored for Amazon.co.jp URIs).

.PARAMETER NoShrink
    Used with -DownloadMetaImage. Downloads the image but does not
    create a shrunk (resized) copy.

.PARAMETER Method
    The HTTP method to use for the web request. Defaults to "GET".

.PARAMETER UserAgent
    The User-Agent string to send with the web request.
    Defaults to "bot".

.PARAMETER Image
    Overrides the scraped 'og:image'. (Ignored for Amazon.co.jp URIs).

.PARAMETER ImagePathOverwrite
    Used with -Card. Replaces the image path in the HTML card
    with a custom path. (Ignored for Amazon.co.jp URIs).

.PARAMETER Title
    Manually overrides the 'title'. (Ignored for Amazon.co.jp URIs).

.PARAMETER Description
    Manually overrides the 'description'. (Ignored for Amazon.co.jp URIs).

.PARAMETER AllMetaData
    Dumps all raw <meta>, <title>, and <link rel="canonical"> tags
    found on the page, then stops processing. (Ignored for Amazon.co.jp URIs).

.PARAMETER ShrinkSize
    Specifies the dimensions for the resized image when using
    -DownloadMetaImage. Defaults to '600x600'.
    (Note: Requires an external 'ConvImage' function/alias).

.PARAMETER Canonical
    Attempts to use the canonical URI (from <link rel="canonical">
    or og:url) instead of the input URI. (Ignored for Amazon.co.jp URIs).

.PARAMETER Cite
    Wraps the -Markdown, -Dokuwiki, or -Html output in <cite> tags.

.PARAMETER Raw
    Outputs the title and URI on separate lines with no formatting.

.PARAMETER DecodeHtml
    Decodes HTML character entities (e.g., '&#12354;' or '&amp;')
    in the title and description fields. (Ignored for Amazon.co.jp URIs).

.EXAMPLE
    PS C:\> "https://github.com/" | Get-OGP | Format-List

    uri         : https://github.com/
    title       : GitHub: Let’s build from here
    description : GitHub is where over...
    image       : https://github.git...........png
    OutputImage :

.EXAMPLE
    PS C:\> "https://www.amazon.co.jp/gp/product/B00N3F408C/ref=foo" | Get-OGP -Markdown

    [](https://www.amazon.co.jp/dp/B00N3F408C)

.EXAMPLE
    PS C:\> Get-OGP "https://github.com/" -DownloadMetaImage | Format-List

    uri         : https://github.com/
    title       : GitHub: Let’s build from here
    description : GitHub is where over 100 million developers...
    image       : https://github.git...........png
    OutputImage : C:\Users\YourUser/............._s.png

.EXAMPLE
    PS C:\> Get-OGP "https://github.com/" -Markdown

    [GitHub: Let’s build from here](https://github.com/)

.EXAMPLE
    PS C:\> Get-OGP "https://github.com/" -Markdown -Id "gh"

    [GitHub: Let’s build from here][gh]
    [gh]: <https://github.com/>

.EXAMPLE
    PS C:\> Get-OGP "https://github.com/" -AllMetaData
    # Dumps all raw meta/title/link tags found.

    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    ...
    <meta property="og:title" content="GitHub: Let’s build from here" />
    ...
    <title>GitHub: Let’s build from here · GitHub</title>

.LINK
    Get-OGP (ml), Get-ClipboardAlternative (gclipa),
    clip2file, clip2push, clip2shortcut,
    clip2img, clip2txt, clip2normalize,
    Get-ScrapingPolicy
#>
function Get-OGP {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$False, ValueFromPipeline=$True)]
        [Alias('u')]
        [string[]] $Uri,

        [Parameter(Mandatory=$False)]
        [Alias('b')]
        [switch] $Card,

        [Parameter(Mandatory=$False)]
        [Alias('m')]
        [switch] $Markdown,

        [Parameter(Mandatory=$False)]
        [Alias('d')]
        [switch] $Dokuwiki,

        [Parameter(Mandatory=$False)]
        [Alias('i')]
        [string] $Id = "@not@set@", # Using a magic string to check if -Id was explicitly set

        [Parameter(Mandatory=$False)]
        [Alias('h')]
        [switch] $Html,

        [Parameter(Mandatory=$False)]
        [Alias('c')]
        [switch] $Clip,

        [Parameter(Mandatory=$False)]
        [switch] $DownloadMetaImage,

        [Parameter(Mandatory=$False)]
        [string] $Method = "GET",

        [Parameter(Mandatory=$False)]
        [string] $UserAgent = "bot",

        [Parameter(Mandatory=$False)]
        [string] $Image,

        [Parameter(Mandatory=$False)]
        [string] $ImagePathOverwrite,

        [Parameter(Mandatory=$False)]
        [string] $Title,

        [Parameter(Mandatory=$False)]
        [string] $Description,

        [Parameter(Mandatory=$False)]
        [switch] $AllMetaData,

        [Parameter(Mandatory=$False)]
        [string] $ShrinkSize = '600x600',

        [Parameter(Mandatory=$False)]
        [switch] $UriEncode,

        [Parameter(Mandatory=$False)]
        [switch] $Canonical,

        [Parameter(Mandatory=$False)]
        [switch] $Cite,

        [Parameter(Mandatory=$False)]
        [switch] $Raw,

        [Parameter(Mandatory=$False)]
        [switch] $NoShrink,

        [Parameter(Mandatory=$False)]
        [switch] $DecodeHtml
    )

    begin {
        # Helper function to normalize common Amazon URL variations to a
        # clean /dp/ASIN format. This improves consistency.
        function Parse-AmazonURI ([string]$amUri){
            if ($amUri -match "/dp/(?<asin>[^/]+)"){
                return "https://www.amazon.co.jp/dp/$($Matches.asin)"
            }
            if ($amUri -match "/gp/product/(?<asin>[^/]+)"){
                return "https://www.amazon.co.jp/dp/$($Matches.asin)"
            }
            if ($amUri -match "/exec/obidos/asin/(?<asin>[^/]+)"){
                return "https://www.amazon.co.jp/dp/$($Matches.asin)"
            }
            if ($amUri -match "/o/ASIN/(?<asin>[^/]+)"){
                return "https://www.amazon.co.jp/dp/$($Matches.asin)"
            }
            # If no match, return the original URI
            return $amUri
        }
    }

    process {
        # If no URI is passed via parameter or pipeline (-Uri),
        # get it from the clipboard. This allows for `gogp` with no args.
        if (-not $PSBoundParameters.ContainsKey('Uri')) {
            [string[]] $Uri = Get-Clipboard -Raw `
                | ForEach-Object { $_ -split "`r*`n" } `
                | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        }

        # Process each URI provided.
        foreach ($singleUri in $Uri) {
            if ( $singleUri -eq $Null -or [string]::IsNullOrWhiteSpace($singleUri) ){
                #Write-Verbose "Skipping empty URI."
                continue
            }
            [string]$currentUri = $singleUri

            # --- Amazon.co.jp Special Handling ---
            # As requested, to avoid scraping Amazon, we only normalize the URI
            # and skip all web requests and data extraction.
            if ($currentUri -match '^https://www\.amazon\.co\.jp/'){
                $currentUri = Parse-AmazonURI $currentUri
                
                # Create a minimal object, as we have no title/desc
                $ogpData                = [ordered]@{}
                $ogpData["uri"]         = $currentUri
                $ogpData["title"]       = ''
                $ogpData["description"] = ''
                $ogpData["image"]       = ''
                $ogpData["OutputImage"] = ''

                # Handle output formats for the Amazon URI
                if( $Markdown ){
                    $markdownLink = if($Id -eq '@not@set@'){
                        "[$($ogpData.title)]($($ogpData.uri))"
                    } else {
                        $ref = if ([string]::IsNullOrEmpty($Id)) { $ogpData.title } else { $Id }
                        "[$($ogpData.title)][$ref]", "[$ref]: <$($ogpData.uri)>"
                    }
                    if ($Cite) { $markdownLink = $markdownLink | ForEach-Object { "<cite>$_</cite>" } }
                    if ($Clip) { $markdownLink | Set-ClipBoard } 
                    else { Write-Output $markdownLink }
                    continue # Skip to next URI
                }
                if( $Dokuwiki ){
                    $dokuwikiLink = "[[{0}|{1}]]" -f $ogpData.uri, $ogpData.title
                    if ($Cite) { $dokuwikiLink = "<cite>$dokuwikiLink</cite>" }
                    if ($Clip) { $dokuwikiLink | Set-ClipBoard }
                    else { Write-Output $dokuwikiLink }
                    continue # Skip to next URI
                }
                if ( $Html ){
                    $htmlLink = "<a href=`"$($ogpData.uri)`">$($ogpData.title)</a>"
                    if ($Cite) { $htmlLink = "<cite>$htmlLink</cite>" }
                    if ($Clip) { $htmlLink | Set-ClipBoard }
                    else { Write-Output $htmlLink }
                    continue # Skip to next URI
                }
                if ( $Raw ){
                    $rawOutput = "$($ogpData.title)", "$($ogpData.uri)"
                    if ($Clip) { $rawOutput | Set-ClipBoard }
                    else { Write-Output $rawOutput }
                    continue # Skip to next URI
                }

                # Default output: the minimal PSCustomObject
                if ($Clip){
                    [pscustomobject] $ogpData `
                        | ConvertTo-Csv -NoTypeInformation `
                        | Set-ClipBoard
                } else {
                    [pscustomobject] $ogpData
                }
                continue # IMPORTANT: Skip to the next URI
            }

            # --- Standard OGP Fetching (for non-Amazon sites) ---
            Write-Verbose "Processing URI: $currentUri"
            try {
                # Fetch the webpage content.
                $webResponse = Invoke-WebRequest `
                        -Uri $currentUri `
                        -Method $Method `
                        -UserAgent $UserAgent

                [string]$statusMessage = $webResponse.StatusCode.ToString() + " " + $webResponse.StatusDescription
                Write-Verbose "$statusMessage"

                # Define Regex to extract all relevant tags in one pass.
                [regex]$metaTagRegex       = '<meta [^>]+>'
                [regex]$titleTagRegex      = '<title>[^<]+</title>'
                [regex]$canonicalLinkRegex = '<link rel="canonical" [^<]+/>'

                # Extract all matching tags from the raw content.
                [string[]] $allMetaTags = @()
                $allMetaTags = $webResponse.RawContent | ForEach-Object {
                    $metaTagRegex.Matches($_) | foreach { Write-Output $_.Value }
                    $titleTagRegex.Matches($_) | foreach { Write-Output $_.Value }
                    $canonicalLinkRegex.Matches($_) | foreach { Write-Output $_.Value }
                }

                # Handle case where no metadata is found.
                if ($allMetaTags -eq $Null ){
                    Write-Error "No meta data found in $currentUri" -ErrorAction Stop
                }

                # If -AllMetaData is used, dump the raw tags and exit this loop.
                if ($AllMetaData){
                    $allMetaTags | ForEach-Object { Write-Output $_ }
                    continue # Skip to the next URI
                }

                # This will be the final output object.
                $ogpData                = [ordered]@{}
                $ogpData["uri"]         = ''
                $ogpData["title"]       = ''
                $ogpData["description"] = ''
                $ogpData["image"]       = ''

                # Intermediate variables to store found values before
                # applying priority rules.
                [string]$ogpTitle       = ''
                [string]$ogpUrl         = ''
                [string]$ogpDescription = ''
                [string]$ogpImage       = ''
                [string]$pageTitle      = ''
                [string]$metaDescription= ''
                [string]$canonicalUri   = ''
                [bool]$shouldDownloadImage = $False

                # Iterate through all found tags to extract properties.
                $allMetaTags | ForEach-Object {
                    [string] $metaTag = [string] $_
                    
                    # Use regex to find 'property', 'content', 'name', and 'href'
                    [string] $prop = $metaTag -replace '^<meta [^<]*property="(?<property>[^"]*)".*$', '$1'
                    [string] $cont = $metaTag -replace '^<meta [^<]*content="(?<content>[^"]*)".*$', '$1'
                    [string] $name = $metaTag -replace '^<meta [^<]*name="(?<name>[^"]*)".*$', '$1'
                    [string] $link = $metaTag -replace '^<link rel="canonical" [^<]*(href="[^"]*").*$', '$1'

                    # Clean up values that didn't match (they'll equal the full $metaTag)
                    if ($prop -match '^<meta') { $prop = '' }
                    if ($cont -match '^<meta') { $cont = '' }
                    if ($name -match '^<meta') { $name = '' }
                    if ($link -match '^<link') { $link = '' }

                    # --- OGP Properties (og:*) ---
                    if (($prop -match 'og:title$') -or ($name -match 'og:title$')){
                        $ogpTitle = $cont
                    }
                    if (($prop -match 'og:url$') -or ($name -match 'og:url$')){
                        $ogpUrl = $cont
                    }
                    if (($prop -match 'og:description$') -or ($name -match 'og:description$')){
                        $ogpDescription = $cont
                    }
                    if (($prop -match 'og:image$') -or ($name -match 'og:image$')){
                        $ogpImage = $cont
                        if ($DownloadMetaImage) {
                            $shouldDownloadImage = $True
                        }
                    }

                    # --- Standard Meta/Link Tags (Fallbacks) ---
                    if (($name -eq "description") -and ($cont -notmatch '^<')){
                        $metaDescription = $cont
                    }
                    if (($name -eq "title") -and ($cont -notmatch '^<')){
                        # Some sites use name="title", treat it like og:title
                        $ogpTitle = $cont
                    }
                    if ($metaTag -match '^<title'){
                        $foundTitle = $metaTag -replace '^<title\>([^<]+)</title>.*$', '$1'
                        if ($foundTitle -notmatch '^<'){
                            $pageTitle = $foundTitle
                        }
                    }
                    if ($link -match '^href='){
                        $canonicalUri = $link -replace 'href="([^"]+)"','$1'
                    }
                }

                # --- Apply Priority Rules and Finalize Data ---

                # Priority for Title: 1. OGP Title, 2. Page Title
                $ogpData["title"] = $ogpTitle
                if ([string]::IsNullOrEmpty($ogpData["title"])) {
                    $ogpData["title"] = $pageTitle
                }

                # Priority for Description: 1. OGP Description, 2. Meta Description
                $ogpData["description"] = $ogpDescription
                if ([string]::IsNullOrEmpty($ogpData["description"])) {
                    $ogpData["description"] = $metaDescription
                }

                # Priority for URI: 1. Canonical (if -Canonical), 2. OGP URL, 3. Input URI
                if ($Canonical -and -not [string]::IsNullOrEmpty($canonicalUri)){
                    $ogpData["uri"] = $canonicalUri
                } elseif (-not [string]::IsNullOrEmpty($ogpUrl)) {
                    $ogpData["uri"] = $ogpUrl
                } else {
                    $ogpData["uri"] = $currentUri
                }
                
                # Set Image
                $ogpData["image"] = $ogpImage

                # Decode HTML entities if requested.
                if ($DecodeHtml) {
                    if (-not [string]::IsNullOrEmpty($ogpData["title"])) {
                        $ogpData["title"] = [System.Net.WebUtility]::HtmlDecode($ogpData["title"])
                    }
                    if (-not [string]::IsNullOrEmpty($ogpData["description"])) {
                        $ogpData["description"] = [System.Net.WebUtility]::HtmlDecode($ogpData["description"])
                    }
                }

                # Allow manual overrides from parameters.
                if ($Title) { $ogpData["title"] = $Title }
                if ($Description) { $ogpData["description"] = $Description }

                # --- Image Handling ---
                
                # This path is for the optional shrunk image.
                $ogpData["OutputImage"] = ''

                # Case 1: -Image parameter is used, overriding OGP image.
                if ($Image) {
                    # Use the provided local image.
                    if($isWindows){ $ogpData["image"] = $Image.Replace('\','/') }
                    else{ $ogpData["image"] = $Image }

                    $downloadPath = (Resolve-Path -LiteralPath $Image).Path
                    $shrunkImagePath = $downloadPath -replace '(\.[^.]+)$','_s$1' # Add _s suffix

                    if (-not $NoShrink){
                        # Note: 'ConvImage' is an external dependency.
                        Write-Verbose "Shrinking provided image: $downloadPath"
                        ConvImage -inputFile $downloadPath -outputFile $shrunkImagePath -resize $ShrinkSize
                        if ($isWindows){ $ogpData["OutputImage"] = $shrunkImagePath.Replace('\','/') }
                        else{ $ogpData["OutputImage"] = $shrunkImagePath }
                    } else {
                        # -NoShrink: The "OutputImage" is just the original.
                        if ($isWindows){ $ogpData["OutputImage"] = $downloadPath.Replace('\','/') }
                        else{ $ogpData["OutputImage"] = $downloadPath }
                    }
                }
                # Case 2: -DownloadMetaImage is used (and -Image was not).
                elseif ($shouldDownloadImage) {
                    $downloadDir = Join-Path -Path $HOME -ChildPath "Downloads"
                    [string]$imageFileName = Split-Path -Path $ogpData["image"] -Leaf
                    # Handle cases where image URI has no filename (e.g., query param)
                    if ([string]::IsNullOrEmpty($imageFileName)) {
                        $imageFileName = "ogp_image_$(Get-Random)"
                    }
                    $downloadPath = Join-Path -Path $downloadDir -ChildPath $imageFileName
                    
                    try {
                        Write-Verbose "Downloading image to: $downloadPath"
                        Invoke-WebRequest -Uri $ogpData["image"] -OutFile $downloadPath
                        
                        $shrunkImagePath = $downloadPath -replace '(\.[^.]+)$','_s$1' # Add _s suffix
                        if (-not $NoShrink){
                            # Note: 'ConvImage' is an external dependency.
                            Write-Verbose "Shrinking downloaded image to: $shrunkImagePath"
                            ConvImage -inputFile $downloadPath -outputFile $shrunkImagePath -resize $ShrinkSize
                            $ogpData["OutputImage"] = $shrunkImagePath
                        } else {
                            # -NoShrink: The "OutputImage" is the downloaded file.
                            $ogpData["OutputImage"] = $downloadPath
                        }
                    } catch {
                        Write-Host "Image download failed: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
                    }
                }
                
                # --- Format Output ---
                
                # -Card: Output as HTML blog card.
                if($Card){
                    # Simple HTML template for the card.
                    $htmlCard = @'
<!-- blog card -->
<a href="{{- .Params.url -}}" style="margin: 50px;padding: 12px;border: solid thin slategray;display: flex;text-decoration: none;color: inherit;" onMouseOver="this.style.opacity='0.9'" target="_blank">
    <div style="flex-shrink: 0;">
        <img src="{{- .Params.image -}}" alt="" width="100" />
    </div>
    <div style="margin-left: 10px;">
        <h2 style="margin: 0;padding-bottom: 13px;border: none;font-size: 16px;">
            {{- .Params.title -}}
        </h2>
        <p style="margin: 0;font-size: 13px;word-break: break-word;display: -webkit-box;-webkit-box-orient: vertical;-webkit-line-clamp: 3;overflow: hidden;">
            {{- .Params.description -}}
        </p>
    </div>
</a>
'@
                    # Replace placeholders with OGP data.
                    $htmlCard = $htmlCard.Replace('{{- .Params.title -}}', $ogpData.title)
                    $htmlCard = $htmlCard.Replace('{{- .Params.url -}}', $ogpData.uri)
                    $htmlCard = $htmlCard.Replace('{{- .Params.description -}}', $ogpData.description)
                    
                    # Use the shrunk image path if it exists, otherwise use the original.
                    $cardImage = $ogpData["OutputImage"]
                    if ([string]::IsNullOrEmpty($cardImage)) {
                        $cardImage = $ogpData["image"]
                    }

                    # Handle -ImagePathOverwrite
                    if($ImagePathOverwrite){
                        $fImage = Split-Path -Path $cardImage -Leaf
                        $cardImage = Join-Path $ImagePathOverwrite $fImage
                        if($isWindows){ $cardImage = $cardImage.Replace('\','/') }
                    }
                    $htmlCard = $htmlCard.Replace('{{- .Params.image -}}', $cardImage)

                    if ($Clip) { $htmlCard | Set-ClipBoard }
                    else { Write-Output $htmlCard }
                    continue # Finished with this URI
                }

                # -Markdown: Output as [title](uri)
                if( $Markdown ){
                    $markdownLink = if($Id -eq '@not@set@'){
                        # Standard inline link
                        "[$($ogpData.title)]($($ogpData.uri))"
                    } else {
                        # Reference-style link
                        $ref = if ([string]::IsNullOrEmpty($Id)) { $ogpData.title } else { $Id }
                        "[$($ogpData.title)][$ref]", "[$ref]: <$($ogpData.uri)>"
                    }
                    if ($Cite) { $markdownLink = $markdownLink | ForEach-Object { "<cite>$_</cite>" } }
                    if ($Clip) { $markdownLink | Set-ClipBoard } 
                    else { Write-Output $markdownLink }
                    continue # Finished with this URI
                }

                # -Dokuwiki: Output as [[uri|title]]
                if( $Dokuwiki ){
                    $dokuwikiLink = "[[{0}|{1}]]" -f $ogpData.uri, $ogpData.title
                    if ($Cite) { $dokuwikiLink = "<cite>$dokuwikiLink</cite>" }
                    if ($Clip) { $dokuwikiLink | Set-ClipBoard }
                    else { Write-Output $dokuwikiLink }
                    continue # Finished with this URI
                }

                # -Html: Output as <a href="uri">title</a>
                if ( $Html ){
                    $htmlLink = "<a href=`"$($ogpData.uri)`">$($ogpData.title)</a>"
                    if ($Cite) { $htmlLink = "<cite>$htmlLink</cite>" }
                    if ($Clip) { $htmlLink | Set-ClipBoard }
                    else { Write-Output $htmlLink }
                    continue # Finished with this URI
                }

                # -Raw: Output as title (newline) uri
                if ( $Raw ){
                    $rawOutput = "$($ogpData.title)", "$($ogpData.uri)"
                    if ($Clip) { $rawOutput | Set-ClipBoard }
                    else { Write-Output $rawOutput }
                    continue # Finished with this URI
                }

                # Default Output: Return the full PSCustomObject.
                if ($Clip){
                    # Convert object to CSV for a reasonable clipboard format.
                    [pscustomobject] $ogpData `
                        | ConvertTo-Csv -NoTypeInformation `
                        | Set-ClipBoard
                } else {
                    # Default behavior: output the object to the pipeline.
                    [pscustomobject] $ogpData
                }
            } catch {
                Write-Host "An error occurred for URI '$currentUri': $($_.Exception.Message)" -ForegroundColor Red
                if ($_.Exception.Response) {
                     Write-Host "HTTP Status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
                }
            }
        } # End foreach URI
    }
}

# --- Alias Setup ---
# set alias
[String] $tmpAliasName = "ml"
[String] $tmpCmdName   = "Get-OGP"
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
