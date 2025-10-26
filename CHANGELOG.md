# Changelog

All notable changes to "[pwsh-sketches](https://github.com/btklab/pwsh-sketches)" project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [unreleased]

- Added [Get-LabelBlock][] function.

## [0.16.1] - 2025-10-19

- Fixed [Join-Blank][], [Join-Step][] Explicitly declare variable types.

## [0.16.0] - 2025-10-19

- Added [Join-Blank][] function.
- Added [Join-Step][] function.
- Added [Read-Immersive][] function.
- Added [Invoke-Link][] immersive reader mode.
- Added [Invoke-Link][] several options for safety and security.
- Fixed [grep][] Branch behavior of the -Context option depending on the number of input files.
- Changed [Invoke-Link][] Remove unnecessary file names from the output when the -ShowHelp option is specified.

## [0.15.0] - 2025-10-05

- Added [Invoke-Link][] label-based block selection.
- Added [Get-Block][] function.
- Added [Convert-Uri2Html][] (Alias: uri2html) function.

## [0.14.0] - 2025-09-14

- Refactored [Get-OGP][] function.
- Refactored [addb][], [addt][] function.
- Changed [ctail][] Supports object input via pipeline.
- Added [Sanitize-FileName][] function.
- Refactored [uniq][] function.

## [0.13.0] - 2025-08-03

- Renamed `Execute-Lang` to [Invoke-Lang][]
- Renamed `Execute-Litedown` to [Invoke-Litedown][]
- Renamed `Execute-RMarkdown` to [Invoke-RMarkdown][]
- Renamed `Execute-TinyTeX` to [Invoke-TinyTeX][]
- Added [Group-Aggregate][] function.
- Changed [head][], [tail][], [chead][], [ctail][] Optimized for memory usage.
- Added [Add-HtmlHeader][] function.
- Added [Resize-Window][] function.
- Added [sleepy][] `-CountDown` option.
- Added [Edit-Property][] Multiple EXPRESSIONS can be specified.
- Added [Get-FullPath][] function.
- Added [Get-RelativePath][] function.
- Added [Invoke-Vivliostyle][] function.
- Added [Get-Gmail][], [Get-Gcalendar][] `-Detail` option.
- Added [sleepy][] `-Until` option.
- Fixed [Get-Gmail][] Incorrect uri.
- Added [ctail][], [chead][] `-Match` option.
- Refactored [ctail][], [chead][] function.
- Updated [Invoke-Link][] Synopsis.

## [0.12.0] - 2025-07-13

- Added [Get-Gmail][] function.
- Added [Get-Gcalendar][] function.
- Added [Decode-MimeHeader][] function.
- Added [Replace-TabLeading][] function.
- Added [Get-YamlFromMarkdown][] function.
- Added [Infer-ObjectSchema][] function.
- Added [Get-Dataset][] `-Library` option.
- Fixed [Shorten-PropertyName][] Property names that do not contain delimiters are now output as-is.
- Fixed [Measure-Summary][] Incorrect mapping of 'Qt75' column to 'Max' value in summary table
- Changed [pwmake][] Replace leading tabs with spaces.

## [0.11.0] - 2025-06-25

- Added [combi][], [combi2][], [cycle][], [dupl][], [perm][], [perm2][], [nest][], [stair][], [subset][] functions inspired by  greymd/egzact: Generate flexible patterns on the shell <https://github.com/greymd/egzact>
- Added [rev2][] Comment for better maintainability.
- Added [pwmake][] Use `@` prefix for targets as a shorthand for `.PHONY`.
- Changed [pwmake][] the behavior to list files when a directory is specified with the `-f` option.
to list files when a directory is passed as an argument to the `-f` option.
- Changed [Invoke-GitBash][] (Alias: gitbash) Rename -InputObject to -TextObject.
- Changed [tateyoko][], [Invoke-GitBash][] Refactor code.


## [0.10.0] - 2025-06-15

- Added [Invoke-GitBash][] (Alias: gitbash) function.
- Added [Compare-Diff2][] (Alias:pwdiff ) function.
- Added [Compare-Diff2Lcs][] (Alias: pwdiffu) function.
- Added [Compare-Diff3][] (Alias: pwdiff3) function.
- Added [pwmake][] Comments.
- Added [Process-CsvColumn][] `-IncludeRow`, `-ExcludeRow`, `-FirstRow` options.
- Added [lcalc2][] Add comments to improve maintainability.
- Changed [Set-DotEnv][] Read `.env` to `.myenv`.

## [0.9.0] - 2025-05-31

- Added [Convert-CharCase][] the corresponding delimiter with the `-AsSentence` switch.
- Added [Convert-CharCase][] parameters `-ExcludePattern`, `-MatchPattern`.
- Added [Replace-InQuote][] `-FirstMatch` option.
- Added [Process-InQuote][] function.
- Added [Process-CsvColumn][] function.
- Added [Invoke-Link][] `-Push` option.
- Changed [pu2java][] default jar file path.

## [0.8.0] - 2025-04-27

- Added [UnZip-GzFile][] function.
- Added [Convert-Pandoc][] function.
- Added [Get-Histogram][] `-SkipBlank` option.
- Added [Measure-Summary][] Count-NA feature.
- Added [Map-Object][] `-DropRowNA`, `-DropColNA`, `-RowSort`, `-ColSort`, `-Ratio`, `-Format` option.
- Added [Calc-CrossTabulation][] `-DropRowNA`, `-DropColNA`, `-RowSort`, `-ColSort` option.
- Added [Add-Id][] Check for duplicated property names.
- Refactored [Unique-Object][] function.
- Added [Get-AppShortcut][] New Act `Rotate Screen`.
- Added [Convert-CharCase][] function.


## [0.7.0] - 2025-04-12

- Changed [README.md][] Reduce-FileSize: move the synopsis from README.md to each function files.

## [0.6.0] - 2025-04-08

- Added [Get-Dataset][] function.
- Added [Map-Object][] function.
- Added [UnMap-Object][] function.
- Added [Calc-CrossTabulation][] function.
- Added [ForEach-Block][] function.
- Added [ForEach-Step][] function.
- Added [ForEach-Label][] function.
- Changed [Convert-DictionaryToPSCustomObject][] Supported ordered hashtable.
- Changed [Join-While][] Option `Trim` to `DisableTrim`.
- Changed [Join-Until][] Option `Trim` to `DisableTrim`.
- Changed [Join-While][] Add `-ReplaceFirstDelimiter` option.
- Changed [Join-Until][] Add `-ReplaceFirstDelimiter` option.
- Changed [Shorten-PropertyName][] Refactor code.

Breaking Changes

- Renamed `fpath` to [Format-Path][]
- Renamed `ConvImage` to [Convert-Image][]

## [0.5.0] - 2025-03-26

- Added [Convert-DictionaryToPSCustomObject][] (Alias:dict2psobject) function.
- Added [Sponge-Property][] Alias unbox.
- Added [Replace-InQuote][] function.
- Changed [Split-HereString][], [Replace-InQuote][], [sed][], [grep][] Synopsis.

## [0.4.0] - 2025-03-24

- Translated [README.md][] from Japanese to English as faithfully as possible.

### Breaking Changes

- Remaned `jl` to [Join-While][]
- Remaned `jl2` to [Join-Until][]

## [0.3.0] - 2025-03-23

- Added [Sponge-Property][] function
- Added [Sponge-Script][] function
- Added [Split-HereString][] function
- Added [Set-DotEnv][] Support for GnuPG decryption

## [0.2.0] - 2025-03-09

- Added [Set-Lang][] function.
- Added `Execute-Lang` function.
- Added [pwmake][] `-PushAndPop` option.
- Changed [pwmake][] command line break handling from concatenation to line break.
- Changed [pwmake][] fix test filepath.
- Added The MIT License into each script file

## [0.1.0] - 2025-02-21

- Init


[README.md]: blob/main/README.md
[CHANGELOG.md]: blob/main/CHANGELOG.md
[examples.md]: blob/main/examples.md

[addb]: src/addb_function.ps1
[addl]: src/addl_function.ps1
[addr]: src/addr_function.ps1
[addt]: src/addt_function.ps1
[cat2]: src/cat2_function.ps1
[catcsv]: src/catcsv_function.ps1
[chead]: src/chead_function.ps1
[clip2img]: src/clip2img_function.ps1
[clipwatch]: src/clipwatch_function.ps1
[conv]: src/conv_function.ps1
[Convert-Image]: src/Convert-Image_function.ps1
[count]: src/count_function.ps1
[csv2sqlite]: src/csv2sqlite_function.ps1
[csv2txt]: src/csv2txt_function.ps1
[ctail]: src/ctail_function.ps1
[delf]: src/delf_function.ps1
[dot2gviz]: src/dot2gviz_function.ps1
[filehame]: src/filehame_function.ps1
[fillretu]: src/fillretu_function.ps1
[flat]: src/flat_function.ps1
[wrap]: src/wrap_function.ps1
[fwatch]: src/fwatch_function.ps1
[gantt2pu]: src/gantt2pu_function.ps1
[Get-DateAlternative]: src/Get-DateAlternative_function.ps1
[Get-OGP]: src/Get-OGP_function.ps1
[getfirst]: src/getfirst_function.ps1
[getlast]: src/getlast_function.ps1
[grep]: src/grep_function.ps1
[gyo]: src/gyo_function.ps1
[han]: src/han_function.ps1
[head]: src/head_function.ps1
[image2md]: src/image2md_function.ps1
[json2txt]: src/json2txt_function.ps1
[juni]: src/juni_function.ps1
[keta]: src/keta_function.ps1
[kinsoku]: src/kinsoku_function.ps1
[lastyear]: src/Get-DateAlternative_function.ps1
[lcalc]: src/lcalc_function.ps1
[linkcheck]: src/linkcheck_function.ps1
[linkextract]: src/linkextract_function.ps1
[logi2dot]: src/logi2dot_function.ps1
[logi2pu]: src/logi2pu_function.ps1
[man2]: src/man2_function.ps1
[map2]: src/map2_function.ps1
[mind2dot]: src/mind2dot_function.ps1
[mind2pu]: src/mind2pu_function.ps1
[nextyear]: src/Get-DateAlternative_function.ps1
[Override-Yaml]: src/Override-Yaml_function.ps1
[pawk]: src/pawk_function.ps1
[pu2java]: src/pu2java_function.ps1
[pwmake]: src/pwmake_function.ps1
[retu]: src/retu_function.ps1
[rev]: src/rev_function.ps1
[rev2]: src/rev2_function.ps1
[say]: src/say_function.ps1
[sed-i]: src/sed-i_function.ps1
[sed]: src/sed_function.ps1
[self]: src/self_function.ps1
[sleepy]: src/sleepy_function.ps1
[sm2]: src/sm2_function.ps1
[table2md]: src/table2md_function.ps1
[tac]: src/tac_function.ps1
[tail]: src/tail_function.ps1
[tarr]: src/tarr_function.ps1
[tateyoko]: src/tateyoko_function.ps1
[teatimer]: src/teatimer_function.ps1
[tenki]: src/tenki_function.ps1
[tex2pdf]: src/tex2pdf_function.ps1
[thisyear]: src/Get-DateAlternative_function.ps1
[toml2psobject]: src/toml2psobject_function.ps1
[uniq]: src/uniq_function.ps1
[vbStrConv]: src/vbStrConv_function.ps1
[yarr]: src/yarr_function.ps1
[zen]: src/zen_function.ps1

[percentile]: src/percentile_function.ps1
[decil]: src/decil_function.ps1
[summary]: src/summary_function.ps1
[movw]: src/movw_function.ps1

[Format-Path]: src/Format-Path_function.ps1
[watercss]: src/watercss_function.ps1

[flow2pu]: src/flow2pu_function.ps1
[seq2pu]: src/seq2pu_function.ps1

[ysort]: src/ysort_function.ps1
[ycalc]: src/ycalc_function.ps1
[fval]: src/fval_function.ps1

[Get-AppShortcut]: src/Get-AppShortcut_function.ps1
[mdgrep]: src/mdgrep_function.ps1

[pwsync]: src/pwsync_function.ps1
[clip2file]: src/clip2file_function.ps1
[Rename-Normalize]: src/Rename-Normalize_function.ps1
[clip2normalize]: src/clip2normalize_function.ps1

[tail-f]: src/tail-f_function.ps1
[operator.ps1]: operator.ps1

[push2loc]: src/push2loc_function.ps1
[clip2push]: src/clip2push_function.ps1
[clip2shortcut]: src/clip2shortcut_function.ps1

[clip2hyperlinkl]: src/clip2hyperlink_function.ps1
[list2table]: src/list2table_function.ps1
[mdfocus]: src/mdfocus_function.ps1

[Add-LineBreak]: src/Add-LineBreak_function.ps1
[Add-LineBreakEndOfFile]: src/Add-LineBreakEndOfFile_function.ps1

[Shorten-PropertyName]: src/Shorten-PropertyName_function.ps1
[Drop-NA]: src/Drop-NA_function.ps1
[Replace-NA]: src/Replace-NA_function.ps1
[Apply-Function]: src/Apply-Function_function.ps1
[GroupBy-Object]: src/GroupBy-Object_function.ps1
[Measure-Stats]: src/Measure-Stats_function.ps1
[Add-Stats]: src/Add-Stats_function.ps1
[Detect-XrsAnomaly]: src/Detect-XrsAnomaly_function.ps1

[Get-Histogram]: src/Get-Histogram_function.ps1
[Plot-BarChart]: src/Plot-BarChart_function.ps1

[Get-First]: src/Get-First_function.ps1
[Get-Last]: src/Get-Last_function.ps1
[Select-Field]: src/Select-Field_function.ps1
[Delete-Field]: src/Delete-Field_function.ps1

[Replace-ForEach]: src/Replace-ForEach_function.ps1

[Measure-Quartile]: src/Measure-Quartile_function.ps1
[Add-Quartile]: src/Add-Quartile_function.ps1

[Join2-Object]: src/Join2-Object_function.ps1

[lcalc2]: src/lcalc2_function.ps1

[Unique-Object]: src/Unique-Object_function.ps1
[Measure-Summary]: src/Measure-Summary_function.ps1
[Transpose-Property]: src/Transpose-Property_function.ps1

[Edit-Function]: src/Edit-Function_function.ps1
[Get-Ticket]: src/Get-Ticket_function.ps1

[Decrease-Indent]: src/Decrease-Indent_function.ps1

[Set-NowTime2Clipboard]: src/Set-NowTime2Clipboard_function.ps1
[Sleep-ComputerAFM]: src/Sleep-ComputerAFM_function.ps1
[Shutdown-ComputerAFM]: src/Shutdown-ComputerAFM_function.ps1

[Unzip-Archive]: src/Unzip-Archive_function.ps1
[clip2unzip]: src/Unzip-Archive_function.ps1

[Get-ClipboardAlternative]: src/Get-ClipboardAlternative_function.ps1
[gclipa]: src/Get-ClipboardAlternative_function.ps1

[Test-isAsciiLine]: src/Test-isAsciiLine_function.ps1
[isAsciiLine]: src/Test-isAsciiLine_function.ps1

[Grep-Block]: src/Grep-Block_function.ps1
[Sort-Block]: src/Sort-Block_function.ps1

[Invoke-TinyTeX]: src/Invoke-TinyTeX_function.ps1
[Invoke-RMarkdown]: src/Invoke-RMarkdown_function.ps1

[math2tex]: src/math2tex_function.ps1
[Inkscape-Converter]: src/Inkscape-Converter_function.ps1

[GetValueFrom-Key]: src/GetValueFrom-Key_function.ps1

[Trim-EmptyLine]: src/Trim-EmptyLine_function.ps1

[Cast-Date]: src/Cast-Date_function.ps1
[Cast-Decimal]: src/Cast-Decimal_function.ps1
[Cast-Double]: src/Cast-Double_function.ps1
[Cast-Integer]: src/Cast-Integer_function.ps1
[Edit-Property]: src/Edit-Property_function.ps1

[ClipImageFrom-File]: src/ClipImageFrom-File_function.ps1

[Invoke-Link]: src/Invoke-Link_function.ps1

[Add-Id]: src/Add-Id_function.ps1

[Tee-Clip]: src/Tee-Clip_function.ps1
[Auto-Clip]: src/Auto-Clip_function.ps1

[PullOut-String]: src/PullOut-String_function.ps1

[Set-DotEnv]: src/Set-DotEnv_function.ps1

[Decode-Uri]: src/Decode-Uri_function.ps1
[Encode-Uri]: src/Encode-Uri_function.ps1

[Set-Lang]: src/Set-Lang_function.ps1
[Invoke-Lang]: src/Invoke-Lang_function.ps1

[Sponge-Property]: src/Sponge-Property_function.ps1
[Sponge-Script]: src/Sponge-Script_function.ps1
[Split-HereString]: src/Split-HereString_function.ps1

[Join-While]: src/Join-While_function.ps1
[Join-Until]: src/Join-Until_function.ps1

[Convert-DictionaryToPSCustomObject]: src/Convert-DictionaryToPSCustomObject_function.ps1
[Replace-InQuote]: src/Replace-InQuote_function.ps1


[ForEach-Block]: src/ForEach-Block_function.ps1
[ForEach-Step]: src/ForEach-Step_function.ps1
[ForEach-Label]: src/ForEach-Label_function.ps1

[Get-Dataset]: src/Get-Dataset_function.ps1
[Map-Object]: src/Map-Object_function.ps1
[UnMap-Object]: src/UnMap-Object_function.ps1
[Calc-CrossTabulation]: src/Calc-CrossTabulation_function.ps1

[Convert-Pandoc]: src/Convert-Pandoc_function.ps1

[UnZip-GzFile]: src/UnZip-GzFile_function.ps1

[Convert-CharCase]: src/Convert-CharCase_function.ps1

[Process-InQuote]: src/Process-InQuote_function.ps1

[Invoke-GitBash]: src/Invoke-GitBash_function.ps1
[Compare-Diff2Lcs]: src/Compare-Diff2Lcs_function.ps1
[Compare-Diff2]: src/Compare-Diff2_function.ps1
[Compare-Diff3]: src/Compare-Diff3_function.ps1

[combi]: src/combi_function.ps1
[combi2]: src/combi2_function.ps1
[cycle]: src/cycle_function.ps1
[dupl]: src/dupl_function.ps1
[perm]: src/perm_function.ps1
[perm2]: src/perm2_function.ps1
[nest]: src/nest_function.ps1
[stair]: src/stair_function.ps1
[subset]: src/subset_function.ps1

[Get-YamlFromMarkdown]: src/Get-YamlFromMarkdown_function.ps1
[Infer-ObjectSchema]: src/Infer-ObjectSchema_function.ps1
[Replace-TabLeading]: src/Replace-TabLeading_function.ps1
[Decode-MimeHeader]: src/Decode-MimeHeader_function.ps1

[Get-Gmail]: src/Get-Gmail_function.ps1
[Get-Gcalendar]: src/Get-Gcalendar_function.ps1

[Invoke-Vivliostyle]: src/Invoke-Vivliostyle_function.ps1
[Get-FullPath]: src/Get-FullPath_function.ps1
[Get-RelativePath]: src/Get-RelativePath_function.ps1
[Resize-Window]: src/Resize-Window_function.ps1
[Add-HtmlHeader]: src/Add-HtmlHeader_function.ps1

[Group-Aggregate]: src/Group-Aggregate_function.ps1
[Sanitize-FileName]: src/Sanitize-FileName_function.ps1

[Get-Block]: src/Get-Block_function.ps1
[Convert-Uri2Html]: src/Convert-Uri2Html_function.ps1

[Read-Immersive]: src/Read-Immersive_function.ps1

[Join-Blank]: src/Join-Blank.ps1
[Join-Step]: src/Join-Step_function.ps1

[Get-LabelBlock]: src/Get-LabelBlock_function.ps1


[unreleased]: https://github.com/btklab/pwsh-sketches/compare/0.16.1..HEAD
[0.16.1]: https://github.com/btklab/pwsh-sketches/releases/tag/0.16.1
[0.16.0]: https://github.com/btklab/pwsh-sketches/releases/tag/0.16.0
[0.15.0]: https://github.com/btklab/pwsh-sketches/releases/tag/0.15.0
[0.14.0]: https://github.com/btklab/pwsh-sketches/releases/tag/0.14.0
[0.13.0]: https://github.com/btklab/pwsh-sketches/releases/tag/0.13.0
[0.12.0]: https://github.com/btklab/pwsh-sketches/releases/tag/0.12.0
[0.11.0]: https://github.com/btklab/pwsh-sketches/releases/tag/0.11.0
[0.10.0]: https://github.com/btklab/pwsh-sketches/releases/tag/0.10.0
[0.9.0]: https://github.com/btklab/pwsh-sketches/releases/tag/0.9.0
[0.8.0]: https://github.com/btklab/pwsh-sketches/releases/tag/0.8.0
[0.7.0]: https://github.com/btklab/pwsh-sketches/releases/tag/0.7.0
[0.6.0]: https://github.com/btklab/pwsh-sketches/releases/tag/0.6.0
[0.5.0]: https://github.com/btklab/pwsh-sketches/releases/tag/0.5.0
[0.4.0]: https://github.com/btklab/pwsh-sketches/releases/tag/0.4.0
[0.3.0]: https://github.com/btklab/pwsh-sketches/releases/tag/0.3.0
[0.2.0]: https://github.com/btklab/pwsh-sketches/releases/tag/0.2.0
[0.1.0]: https://github.com/btklab/pwsh-sketches/releases/tag/0.1.0

