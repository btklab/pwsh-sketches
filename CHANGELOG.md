# Changelog

All notable changes to "[pwsh-sketches](https://github.com/btklab/pwsh-sketches)" project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [unreleased]

- Added [Get-Histogram][] `-SkipBlank` option.
- Added [Measure-Summary][] Count-NA feature.
- Added [Map-Object][] `-DropRowNA`, `-DropColNA`, `-RowSort`, `-ColSort` option.
- Added [Calc-CrossTabulation][] `-DropRowNA`, `-DropColNA`, `-RowSort`, `-ColSort` option.
- Added [Add-Id][] Check for duplicated property names.

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
- Added [Execute-Lang][] function.
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

[Execute-TinyTeX]: src/Execute-TinyTeX_function.ps1
[Execute-RMarkdown]: src/Execute-RMarkdown_function.ps1

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
[Execute-Lang]: src/Execute-Lang_function.ps1

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


[unreleased]: https://github.com/btklab/pwsh-sketches/compare/0.7.0..HEAD
[0.7.0]: https://github.com/btklab/pwsh-sketches/releases/tag/0.6.0
[0.6.0]: https://github.com/btklab/pwsh-sketches/releases/tag/0.6.0
[0.5.0]: https://github.com/btklab/pwsh-sketches/releases/tag/0.5.0
[0.4.0]: https://github.com/btklab/pwsh-sketches/releases/tag/0.4.0
[0.3.0]: https://github.com/btklab/pwsh-sketches/releases/tag/0.3.0
[0.2.0]: https://github.com/btklab/pwsh-sketches/releases/tag/0.2.0
[0.1.0]: https://github.com/btklab/pwsh-sketches/releases/tag/0.1.0

