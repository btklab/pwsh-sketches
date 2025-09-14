<#
.SYNOPSIS
    Get-OGP (Alias:ml) - Make Link with markdown format

    Get meta-OGP tag from uri and format markdown href.

    If Uri is not specified in the args or pipline input,
    it tries to use the value from the clipboard.

    Pick up the following metadata:
      <meta property="og:title" content="Build software...">
      <meta property="og:url" content="https://github.com">
      <meta property="og:image" content="https://github....octocat.png">
      <meta property="og:description" content="GitHub is where...">
      <title>site_title</title>

    -AllMetaData : output all metadata
    -Card: output in BlogCard style html link (no css required)

    -DownloadMetaImage : Download image in the "~/Downloads" and
    resize image to 600x600px. If you only need to acquire
    images without shrinking, add "-NoShrink" option as well.

    Title is retrieved in the following order:
      <meta property="og:title"... />
      <title>site_title</title>

    Description is obtained in the following order:
      <meta property="og:description"... />
      <meta name="description"... />

    -ImagePathOverwrite '/img/2022/' -Card would change
    the image file path in the card style html link to
    any path.

    -Markdown switch to output in [label](uri) format.
        thanks: goark/ml: Make Link with Markdown Format
        <https://github.com/goark/ml>

    -Dokuwiki switch to output in [[uri|title]] format.


.DESCRIPTION
    This function fetches OGP and other metadata (like title,
    description, image) from a given URI. It can process multiple
    URIs provided as arguments, through the pipeline, or from the
    clipboard.

    If no URI is provided via parameters or the pipeline, the
    function attempts to read URIs from the clipboard (one URI per
    line).

    -DecodeHtml: Decodes HTML character entities found in the title
    and description.

.LINK
    Get-OGP (ml), Get-ClipboardAlternative (gclipa),
    clip2file, clip2push, clip2shortcut,
    clip2img, clip2txt, clip2normalize

.PARAMETER Uri
    The URI(s) to retrieve OGP data from. Accepts multiple values
    and pipeline input. If omitted, it reads from the clipboard.

.PARAMETER Canonical
    get canonical uri

.PARAMETER Markdown
    Return links in markdown format
    like: [title](uri)

.PARAMETER Dokuwiki
    Return links in dokuwiki format
    like: [[uri|title]]

.PARAMETER Cite
    Wrap Markdown and Html output in "<cite>" tag

.PARAMETER Id
    Returns a separate line link when used in
    conjunction with the -Markdown switch

      [title][key]
      [key]: <uri>

    If -Id "" and then:

      [GitHub: Let’s build from here][]
      [GitHub: Let’s build from here]: <https://github.com/>

.PARAMETER Raw
    Returns a link without parenthesis

      title
      uri

.PARAMETER DecodeHtml
    If specified, decodes HTML character entities (e.g., '&#12354;') in the title and description.

.EXAMPLE
    "https://github.com/" | Get-OGP | fl

    uri         : https://github.com/
    title       : GitHub: Let’s build from...
    description : GitHub is where over...
    image       : https://github...social.png

.EXAMPLE
    Get-OGP "https://github.com/" | fl

    uri         : https://github.com/
    title       : GitHub: Let’s build from...
    description : GitHub is where over...
    image       : https://github...social.png

.EXAMPLE
    Get-OGP "https://github.com/" -DownloadMetaImage | fl

    uri         : https://github.com/
    title       : GitHub: Let’s build from...
    description : GitHub is where over...
    image       : https://github...social.png
    OutputImage : ~/Downloads/campaign-social_s.png

.EXAMPLE
    "https://github.com/" | Get-OGP -AllMetaData

    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width">
    <meta name="description" content="GitHub is where...">
    <meta property="og:image" content="https://github....social.png" />
    <meta property="og:image:alt" content="GitHub is..." />
    <meta property="og:site_name" content="GitHub" />
    <meta property="og:type" content="object" />
    <meta property="og:title" content="GitHub: Let’s build..." />
    <meta property="og:url" content="https://github.com/" />
    <meta property="og:description" content="GitHub is where..." />
    <title>GitHub: Let’s build from here · GitHub</title>

.EXAMPLE
    # -Image <image_file> to replace image with a local image file,
    # and shrink the replaced local image file to 600x600px.
    Get-OGP "https://github.com/" -DownloadMetaImage -Image ~/Downloads/hoge.png | fl

    uri         : https://github.com/
    title       : GitHub: Let’s build from...
    description : GitHub is where over...
    image       : ~/Downloads/hoge.png
    OutputImage : ~/Downloads/campaign-social_s.png


.EXAMPLE
    # Card format
    Get-OGP "https://github.com/"-DownloadMetaImage -Card | fl

    <!-- blog card -->
    <a href="https://github.com/" style="margin: 50px;padding: 12px;border: solid thin slategray;display: flex;text-decoration: none;color: inherit;" onMouseOver="this.style.opacity='0.9'" target="_blank">
        <div style="flex-shrink: 0;">
            <img src="~/Downloads/campaign-social_s.png" alt="" width="100" />
        </div>
        <div style="margin-left: 10px;">
            <h2 style="margin: 0;padding-bottom: 13px;border: none;font-size: 16px;">
                GitHub: Let’s build from here
            </h2>
            <p style="margin: 0;font-size: 13px;word-break: break-word;display: -webkit-box;-webkit-box-orient: vertical;-webkit-line-clamp: 3;overflow: hidden;">
                GitHub is where over 94 million developers...
            </p>
        </div>
    </a>

.EXAMPLE
    # -Card -ImagePathOverwrite <path> to replace the directory path of the
    # image to be embedded in the Card format/
    Get-OGP "https://www.maff.go.jp/j/shokusan/sdgs/" -ImagePathOverwrite '/img/2022/' -Card

    <!-- blog card -->
    <a href="https://www.maff.go.jp/j/shokusan/sdgs/" style="margin: 50px;padding: 12px;border: solid thin slategray;display: flex;text-decoration: none;color: inherit;" onMouseOver="this.style.opacity='0.9'">
        <div style="flex-shrink: 0;">
            <img src="/img/2022/a_s.png" alt="" width="100" />
        </div>
        <div style="margin-left: 10px;">
            <h2 style="margin: 0;padding-bottom: 13px;border: none;font-size: 16px;">
                SDGs x maff
            </h2>
            <p style="margin: 0;font-size: 13px;word-break: break-word;display: -webkit-box;-webkit-box-orient: vertical;-webkit-line-clamp: 3;overflow: hidden;">
                description
            </p>
        </div>
    </a>

.EXAMPLE
    # Attempt to retrieve the canonical uri with "-Canonical" switch.
    # If not found canonical uri, output the input uri as is.
    Get-OGP "https://github.com/" -Canonical -Markdown | Set-Clipboard

    [GitHub: Let’s build from here](https://github.com/)

.EXAMPLE
    Get-OGP "https://github.com/" -Canonical -Markdown -id ""

    [GitHub: Let’s build from here][]
    [GitHub: Let’s build from here]: <https://github.com/>

.EXAMPLE
    Get-OGP "https://github.com/" -Canonical -Html

    <a href="https://github.com/">GitHub: Let’s build from here</a>

.EXAMPLE
    # Processes the URI and decodes the description and title to readable characters.
    "https://www.google.com" | Get-OGP -DecodeHtml

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
        [string] $Id = "@not@set@",

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
        # Helper function to normalize Amazon URLs to a consistent format.
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
            return $amUri
        }
    }

    process {
        # If no URI is passed via parameter or pipeline, get it from the clipboard.
        if (-not $PSBoundParameters.ContainsKey('Uri')) {
            [string[]] $Uri = Get-Clipboard -Raw `
                | ForEach-Object { $_ -split "`r*`n" } `
                | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        }

        # Process each URI provided.
        foreach ($singleUri in $Uri) {
            [string]$currentUri = $singleUri
            if ($currentUri -match '^https://www\.amazon\.co\.jp/'){
                $currentUri = Parse-AmazonURI $currentUri
            }
            Write-Verbose "curl $currentUri"

            try {
                $res = Invoke-WebRequest `
                        -Uri $currentUri `
                        -Method $Method `
                        -UserAgent $UserAgent

                [string] $debStr = $res.StatusCode.ToString() + " " + $res.StatusDescription
                Write-Verbose "$debStr"

                [regex] $reg      = '<meta [^>]+>'
                [regex] $regTitle = '<title>[^<]+</title>'
                [regex] $regLink  = '<link rel="canonical" [^<]+/>'

                [string[]] $metaAry = @()
                $metaAry = $res.RawContent | ForEach-Object {
                    $reg.Matches($_) | foreach { Write-Output $_.Value }
                    $regTitle.Matches($_) | foreach { Write-Output $_.Value }
                    $regLink.Matches($_) | foreach { Write-Output $_.Value }
                }
                if ($metaAry -eq $Null ){
                    Write-Error "No meta data found in $currentUri" -ErrorAction Stop
                }
                if ($AllMetaData){
                    $metaAry | ForEach-Object { Write-Output $_ }
                    continue
                }

                $o                = [ordered]@{}
                $o["uri"]         = ''
                $o["title"]       = ''
                $o["description"] = ''
                $o["image"]       = ''
                [string] $innerTitle   = ''
                [string] $innerUri     = ''
                [string] $canonicalUri = ''
                [string] $innerImage   = ''
                [string] $innerDesc    = ''
                [bool] $imageFlag   = $False

                # Iterate through meta tags to extract properties.
                $metaAry | ForEach-Object {
                    [string] $metaTag = [string] $_
                    [string] $prop = $metaTag -replace '^<meta [^<]*property="(?<property>[^"]*)".*$', '$1'
                    [string] $cont = $metaTag -replace '^<meta [^<]*content="(?<content>[^"]*)".*$', '$1'
                    [string] $name = $metaTag -replace '^<meta [^<]*name="(?<name>[^"]*)".*$', '$1'
                    [string] $link = $metaTag -replace '^<link rel="canonical" [^<]*(href="[^"]*").*$', '$1'

                    if (($name -eq "description") -and ($cont -notmatch '^<')){
                        $innerDesc = $cont
                        $o["description"] = $innerDesc
                    } elseif (($name -eq "title") -and ($cont -notmatch '^<')){
                        $innerTitle = $cont
                        $o["title"] = $innerTitle
                    } else {
                        if (($prop -match 'og:title$') -or ($name -match 'og:title$')){
                            $innerTitle = $cont
                            if ($o["title"] -eq $Null){
                                $o["title"] = $cont
                            }
                        }
                        if (($prop -match 'og:url$') -or ($name -match 'og:url$')){
                            $innerUri = $cont
                            $o["uri"] = $cont
                        }
                        if (($prop -match 'og:description$') -or ($name -match 'pg:description$')){
                            $innerDesc = $cont
                            $o["description"] = $cont
                        }
                        if (($prop -match 'og:image$') -or ($name -match 'og:image$')){
                            $innerImage = $cont
                            if ($o["image"] -eq $Null){
                                $o["image"] = $cont
                            }
                        }
                        if ($link -match '^href='){
                            $canonicalUri = $link -replace 'href="([^"]+)"','$1'
                        }
                        # Flag for image download
                        if ($DownloadMetaImage -and (($prop -match 'og:image$') -or ($name -match 'og:image$'))){
                            $imageFlag = $True
                            [string] $imageUri = $cont
                            [string] $imageFileName = Split-Path -Path $imageUri -Leaf
                        }
                    }
                }
                
                # Fallback to <title> tag if OGP title is not found.
                if ([string]::IsNullOrEmpty($innerTitle)) {
                    $metaAry | ForEach-Object {
                        [string] $metaTag = [string] $_
                        if ($metaTag -match '^<title'){
                            $foundTitle = $metaTag -replace '^<title\>([^<]+)</title>.*$', '$1'
                            if ($foundTitle -notmatch '^<'){
                                $innerTitle = $foundTitle
                                $o["title"] = $innerTitle
                            }
                        }
                    }
                }
                
                # Decode HTML entities if the switch is used.
                if ($DecodeHtml) {
                    if (-not [string]::IsNullOrEmpty($innerTitle)) {
                        $innerTitle = [System.Net.WebUtility]::HtmlDecode($innerTitle)
                    }
                    if (-not [string]::IsNullOrEmpty($innerDesc)) {
                        $innerDesc = [System.Net.WebUtility]::HtmlDecode($innerDesc)
                    }
                }

                # Set final URI, preferring canonical if requested.
                if ($Canonical -and -not [string]::IsNullOrEmpty($canonicalUri)){
                    $innerUri = $canonicalUri
                } elseif ([string]::IsNullOrEmpty($innerUri)){
                    $innerUri = $currentUri
                }
                
                # (Re)assign properties to the output object after potential decoding.
                $o["title"] = $innerTitle
                $o["uri"] = $innerUri
                $o["description"] = $innerDesc
                $o["image"] = $innerImage


                # Allow overriding metadata with parameters.
                if ($Title) { $o["title"] = $Title }
                if ($Description) { $o["description"] = $Description }

                # (The rest of the script remains the same...)
                # Handle image download and processing...
                if ($Image) {
                    if($isWindows){ $o["image"] = $Image.Replace('\','/') }
                    else{ $o["image"] = $Image }

                    $dlPath = (Resolve-Path -LiteralPath $Image).Path
                    $oFile = $dlPath -replace '(\.[^.]+)$','_s$1'

                    if (-not $NoShrink){
                        ConvImage -inputFile $dlPath -outputFile $oFile -resize $ShrinkSize
                        if ($isWindows){ $o["OutputImage"] = $oFile.Replace('\','/') }
                        else{ $o["OutputImage"] = $oFile }
                    } else {
                        if ($isWindows){ $o["OutputImage"] = $dlPath.Replace('\','/') }
                        else{ $o["OutputImage"] = $dlPath }
                    }
                } elseif ($imageFlag) {
                    $dlDirName = Join-Path -Path $HOME -ChildPath "Downloads"
                    $dlPath = Join-Path -Path $dlDirName -ChildPath $imageFileName
                    try {
                        Invoke-WebRequest -Uri $imageUri -OutFile $dlPath
                        $oFile = $dlPath -replace '(\.[^.]+)$','_s$1'
                        if (-not $NoShrink){
                            ConvImage -inputFile $dlPath -outputFile $oFile -resize $ShrinkSize
                            $o["OutputImage"] = $oFile
                        } else {
                            $o["OutputImage"] = $dlPath
                        }
                    } catch {
                        Write-Host "Image download failed: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
                    }
                }
                
                # Format and generate output based on switches.
                if($Card){
                    $oHtml = @'
<a href="{{- .Params.url -}}" style="margin: 50px;padding: 12px;border: solid thin slategray;display: flex;text-decoration: none;color: inherit;" onMouseOver="this.style.opacity='0.9'" target="_blank">
    <div style="flex-shrink: 0;">
        <img src="{{- .Params.image -}}" alt="" width="100" />
    </div>
    <div style="margin-left: 10px;">
        <h2 style="margin: 0;padding-bottom: 13px;border: none;font-size: 16px;">
            {{- .Params.title -}}
        </h2>
        <p style="margin: 0;font-size: 13px;word-break: break-word;display: -webkit-box;-webkit-box-orient: vertical;-webkit-line-clamp: 3;overflow: hidden;">
            {{- .Params.description | plainify | safeHTML -}}
        </p>
    </div>
</a>
'@
                    $oHtml = $oHtml.Replace('{{- .Params.title -}}', $o.title)
                    $oHtml = $oHtml.Replace('{{- .Params.url -}}', $o.uri)
                    $oHtml = $oHtml.Replace('{{- .Params.description | plainify | safeHTML -}}', $o.description)
                    
                    $uImage = $o["OutputImage"]
                    if($ImagePathOverwrite){
                        $fImage = Split-Path -Path $uImage -Leaf
                        $uImage = Join-Path $ImagePathOverwrite $fImage
                        if($isWindows){$uImage = $uImage.Replace('\','/')}
                    }
                    $oHtml = $oHtml.Replace('{{- .Params.image -}}', $uImage)

                    if ($Clip) { $oHtml | Set-ClipBoard }
                    else { Write-Output $oHtml }
                    continue
                }
                if( $Markdown ){
                    $oMarkdown = if($Id -eq '@not@set@'){
                        "[$($o.title)]($($o.uri))"
                    } else {
                        $ref = if ([string]::IsNullOrEmpty($Id)) { $o.title } else { $Id }
                        "[$($o.title)][$ref]", "[$ref]: <$($o.uri)>"
                    }
                    if ($Cite) { $oMarkdown = $oMarkdown | ForEach-Object { "<cite>$_</cite>" } }
                    if ($Clip) { $oMarkdown | Set-ClipBoard } 
                    else { Write-Output $oMarkdown }
                    continue
                }
                if( $Dokuwiki ){
                    $oDokuwiki = "[[{0}|{1}]]" -f $o.uri, $o.title
                    if ($Cite) { $oDokuwiki = "<cite>$oDokuwiki</cite>" }
                    if ($Clip) { $oDokuwiki | Set-ClipBoard }
                    else { Write-Output $oDokuwiki }
                    continue
                }
                if ( $Html ){
                    $oHref = "<a href=`"$($o.uri)`">$($o.title)</a>"
                    if ($Cite) { $oHref = "<cite>$oHref</cite>" }
                    if ($Clip) { $oHref | Set-ClipBoard }
                    else { Write-Output $oHref }
                    continue
                }
                if ( $Raw ){
                    $oRaw = "$($o.title)", "$($o.uri)"
                    if ($Clip) { $oRaw | Set-ClipBoard }
                    else { Write-Output $oRaw }
                    continue
                }

                # Default output is a custom object.
                if ($Clip){
                    [pscustomobject] $o `
                        | ConvertTo-Csv -NoTypeInformation `
                        | Set-ClipBoard
                } else {
                    [pscustomobject] $o
                }
            } catch {
                Write-Host "An error occurred for URI '$currentUri': $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
            }
        } # End foreach URI
    }
}

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
