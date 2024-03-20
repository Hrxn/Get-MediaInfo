# -------------------------------------------------- Local Functions --------------------------------------------------

function ConvertStringToDouble($Value) {
	$Result = $null
	if ([double]::TryParse($Value, [Globalization.CultureInfo]::InvariantCulture, [ref] $Result)) {
		return $Result
	} else {
		return [double] 0.0
	}
}

function ConvertStringToLong($Value) {
	$Result = $null
	if ([long]::TryParse($Value, [Globalization.CultureInfo]::InvariantCulture, [ref] $Result)) {
		return $Result
	} else {
		return [long] 0
	}
}

function ConvertStringToInt($Value) {
	$Result = $null
	if ([int]::TryParse($Value, [Globalization.CultureInfo]::InvariantCulture, [ref] $Result)) {
		return $Result
	} else {
		return [int] 0
	}
}

# ------------------------------------------------------ Exports ------------------------------------------------------

function Get-MediaInfo {
	[CmdletBinding()]
	[Alias('gmi')]
	param(
		[Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias('FullName', 'Name')]
		[string[]] $Path,

		[switch] $Video,

		[switch] $Audio,

		[switch] $ConvertValues,

		[switch] $WriteCache,

		[switch] $SkipCache
	)

	begin {
		$CacheRoot = Join-Path ([IO.Path]::GetTempPath()) 'Get-MediaInfo-Cache'

		if ($WriteCache) {
			if (-not [IO.Directory]::Exists($CacheRoot)) {
				[Void][IO.Directory]::CreateDirectory($CacheRoot)
			}
		}

		Add-Type -Path ($PSScriptRoot + '\MediaInfoSharp.dll')

		$VideoExtensions =
		'264', '265', 'asf', 'avc', 'avi', 'divx', 'flv', 'h264', 'h265', 'hevc', 'm2ts', 'm2v', 'm4v', 'mkv', 'mov', 'mp4',
		'mpeg', 'mpg', 'mpv', 'mts', 'ogv', 'ts', 'vob', 'webm', 'wmv', 'mpg2', 'mpeg2'
		$AudioExtensions =
		'aac', 'ac3', 'dts', 'dtshd', 'dtshr', 'dtsma', 'eac3', 'flac', 'm4a', 'mka', 'mp2', 'mp3', 'mpa', 'ogg', 'opus', 'thd', 'w64', 'wav', 'oga'
	}

	process {
		$Path = foreach ($p in $Path) { if ($p) { $p } }

		if ([String]::IsNullOrWhiteSpace($Path)) {
			Write-Output ("`e[90m[`e[97mGet-MediaInfo`e[90m][`e[33mInfo`e[90m]`e[0m : No value provided for the parameter `e[32mPath`e[0m. Please specify the path" +
				"to one (or more) files!")
			return
		} elseif ([WildcardPattern]::ContainsWildcardCharacters($Path)) {
			$FileSet = Get-ChildItem -Path $Path -File -ErrorAction Ignore
		} else {
			$FileSet = $Path
		}

		foreach ($Entry in $FileSet) {
			$Realpath = Convert-Path -LiteralPath $Entry -ErrorAction Ignore
			if (-not [IO.File]::Exists($Realpath)) {
				Write-Output "`e[90m[`e[97mGet-MediaInfo`e[90m][`e[31mError`e[90m]`e[0m : Invalid path argument given: `e[90m'`e[94m$Entry`e[90m'`e[0m does not exist as a file!"
				continue
			}

			$Extension = [IO.Path]::GetExtension($Realpath).TrimStart([char]'.')

			$CacheFileBase = $Realpath + '_' + (Get-Item -LiteralPath $Realpath).Length
			foreach ($Char in [IO.Path]::GetInvalidFileNameChars()) {
				if ($CacheFileBase.Contains($Char)) {
					$CacheFileBase = $CacheFileBase.Replace($Char.ToString(), '_')
				}
			}
			$CacheFile = Join-Path $CacheRoot ($CacheFileBase + '.json')

			if (!$Video -and !$Audio) {
				if ($Extension -in $VideoExtensions) {
					$Video = $true
				} elseif ($Extension -in $AudioExtensions) {
					$Audio = $true
				}
			}

			if ($Video) {
				if ([IO.File]::Exists($CacheFile) -and !$SkipCache) {
					Get-Content -LiteralPath $CacheFile -Raw | ConvertFrom-Json
				} else {
					$MediaInfo = [MediaInfoSharp]::new($Realpath)

					$VideoFormat = $MediaInfo.GetInfo('Video', 0, 'Format/String')
					$Container = $MediaInfo.GetInfo('General', 0, 'Format/String')

					if ([String]::Empty -eq $MediaInfo.GetInfo('Video', 0, 'BitRate')) {
						$BitrateKind = 'General'
						$BitrateParam = 'OverallBitRate'
					} else {
						$BitrateKind = 'Video'
						$BitrateParam = 'BitRate'
					}

					if ($ConvertValues) {
						$Output = [pscustomobject]@{
							Name            = [IO.Path]::GetFileName($Realpath)
							Type            = $Extension.ToUpperInvariant()
							Duration        = (ConvertStringToDouble $MediaInfo.GetInfo('General', 0, 'Duration')) / 60000
							Size            = (ConvertStringToLong $MediaInfo.GetInfo('General', 0, 'FileSize')) / 1mb
							ContainerFormat = $Container
							VideoCodec      = $VideoFormat
							Width           = ConvertStringToInt $MediaInfo.GetInfo('Video', 0, 'Width')
							Height          = ConvertStringToInt $MediaInfo.GetInfo('Video', 0, 'Height')
							FramerateMode   = $MediaInfo.GetInfo('Video', 0, 'FrameRate_Mode')
							Framerate       = ConvertStringToDouble $MediaInfo.GetInfo('Video', 0, 'FrameRate')
							VideoBitrate    = (ConvertStringToInt $MediaInfo.GetInfo($BitrateKind, 0, $BitrateParam)) / 1000
							DAR             = ConvertStringToDouble $MediaInfo.GetInfo('Video', 0, 'DisplayAspectRatio')
							FormatProfile   = $MediaInfo.GetInfo('Video', 0, 'Format_Profile')
							ScanType        = $MediaInfo.GetInfo('Video', 0, 'ScanType')
							Colorspace      = $MediaInfo.GetInfo('Video', 0, 'ColorSpace')
							Range           = $MediaInfo.GetInfo('Video', 0, 'colour_range')
							Primaries       = $MediaInfo.GetInfo('Video', 0, 'colour_primaries')
							Transfer        = $MediaInfo.GetInfo('Video', 0, 'transfer_characteristics')
							Matrix          = $MediaInfo.GetInfo('Video', 0, 'matrix_coefficients')
							AudioCodec      = $MediaInfo.GetInfo('General', 0, 'Audio_Codec_List')
							TextFormat      = $MediaInfo.GetInfo('General', 0, 'Text_Format_List')
							Directory       = [IO.Path]::GetDirectoryName($Realpath)
						}
					} else {
						$Output = [pscustomobject]@{
							Name            = [IO.Path]::GetFileName($Realpath)
							Type            = $Extension.ToUpperInvariant()
							Duration        = $MediaInfo.GetInfo('General', 0, 'Duration/String1')
							Size            = $MediaInfo.GetInfo('General', 0, 'FileSize/String4')
							ContainerFormat = $Container
							VideoCodec      = $VideoFormat
							Width           = $MediaInfo.GetInfo('Video', 0, 'Width')
							Height          = $MediaInfo.GetInfo('Video', 0, 'Height')
							FramerateMode   = $MediaInfo.GetInfo('Video', 0, 'FrameRate_Mode')
							Framerate       = $MediaInfo.GetInfo('Video', 0, 'FrameRate/String')
							VideoBitrate    = $MediaInfo.GetInfo($BitrateKind, 0, "${BitrateParam}/String")
							DAR             = $MediaInfo.GetInfo('Video', 0, 'DisplayAspectRatio/String')
							FormatProfile   = $MediaInfo.GetInfo('Video', 0, 'Format_Profile')
							ScanType        = $MediaInfo.GetInfo('Video', 0, 'ScanType')
							Colorspace      = $MediaInfo.GetInfo('Video', 0, 'ColorSpace')
							Range           = $MediaInfo.GetInfo('Video', 0, 'colour_range')
							Primaries       = $MediaInfo.GetInfo('Video', 0, 'colour_primaries')
							Transfer        = $MediaInfo.GetInfo('Video', 0, 'transfer_characteristics')
							Matrix          = $MediaInfo.GetInfo('Video', 0, 'matrix_coefficients')
							AudioCodec      = $MediaInfo.GetInfo('General', 0, 'Audio_Codec_List')
							TextFormat      = $MediaInfo.GetInfo('General', 0, 'Text_Format_List')
							Directory       = [IO.Path]::GetDirectoryName($Realpath)
						}
					}

					$MediaInfo.Dispose()
					if ($WriteCache) {
						$Output | ConvertTo-Json | Out-File -LiteralPath $CacheFile -Encoding UTF8
					}
					Write-Output $Output
				}
			} elseif ($Audio) {
				if ([IO.File]::Exists($CacheFile) -and !$SkipCache) {
					Get-Content -LiteralPath $CacheFile -Raw | ConvertFrom-Json
				} else {
					$MediaInfo = [MediaInfoSharp]::new($Realpath)

					if ($ConvertValues) {
						$Output = [pscustomobject]@{
							Name        = [IO.Path]::GetFileName($Realpath)
							Type        = $Extension.ToUpperInvariant()
							Format      = $MediaInfo.GetInfo('Audio', 0, 'Format')
							Performer   = $MediaInfo.GetInfo('General', 0, 'Performer')
							Track       = $MediaInfo.GetInfo('General', 0, 'Track')
							Album       = $MediaInfo.GetInfo('General', 0, 'Album')
							Year        = $MediaInfo.GetInfo('General', 0, 'Recorded_Date')
							Genre       = $MediaInfo.GetInfo('General', 0, 'Genre')
							Duration    = (ConvertStringToDouble $MediaInfo.GetInfo('General', 0, 'Duration')) / 60000
							Bitrate     = (ConvertStringToInt $MediaInfo.GetInfo('Audio', 0, 'BitRate')) / 1000
							BitrateMode = $MediaInfo.GetInfo('Audio', 0, 'BitRate_Mode')
							Size        = (ConvertStringToLong $MediaInfo.GetInfo('General', 0, 'FileSize')) / 1mb
							Directory   = [IO.Path]::GetDirectoryName($Realpath)
						}
					} else {
						$Output = [pscustomobject]@{
							Name        = [IO.Path]::GetFileName($Realpath)
							Type        = $Extension.ToUpperInvariant()
							Format      = $MediaInfo.GetInfo('Audio', 0, 'Format')
							Performer   = $MediaInfo.GetInfo('General', 0, 'Performer')
							Track       = $MediaInfo.GetInfo('General', 0, 'Track')
							Album       = $MediaInfo.GetInfo('General', 0, 'Album')
							Year        = $MediaInfo.GetInfo('General', 0, 'Recorded_Date')
							Genre       = $MediaInfo.GetInfo('General', 0, 'Genre')
							Duration    = $MediaInfo.GetInfo('General', 0, 'Duration/String1')
							Bitrate     = $MediaInfo.GetInfo('Audio', 0, 'BitRate/String')
							BitrateMode = $MediaInfo.GetInfo('Audio', 0, 'BitRate_Mode')
							Size        = $MediaInfo.GetInfo('General', 0, 'FileSize/String4')
							Directory   = [IO.Path]::GetDirectoryName($Realpath)
						}
					}

					$MediaInfo.Dispose()
					if ($WriteCache) {
						$Output | ConvertTo-Json | Out-File -LiteralPath $CacheFile -Encoding UTF8
					}
					Write-Output $Output
				}
			}
		}
	}
}

function Get-MediaInfoValue {
	[CmdletBinding()]
	[Alias('gmiv')]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[string] $Path,

		[Parameter(Mandatory = $true)]
		[ValidateSet('General', 'Video', 'Audio', 'Text', 'Image', 'Menu')]
		[string] $Kind,

		[Parameter(Mandatory = $true)]
		[string] $Parameter,

		[int] $StreamIndex = 0
	)

	begin {
		Add-Type -Path ($PSScriptRoot + '\MediaInfoSharp.dll')
	}

	process {
		$Realpath = Convert-Path -LiteralPath $Path -ErrorAction Ignore
		if ([IO.File]::Exists($Realpath)) {
			$MediaInfo = [MediaInfoSharp]::new($Realpath)
			$Value = $MediaInfo.GetInfo($Kind, $StreamIndex, $Parameter)
			$MediaInfo.Dispose()
			Write-Output $Value
		} else {
			Write-Output "`e[90m[`e[97mGet-MediaInfoValue`e[90m][`e[31mError`e[90m]`e[0m : Invalid path argument given: `e[90m'`e[94m$Path`e[90m'`e[0m is not a file!"
		}
	}
}

function Get-MediaInfoSummary {
	[CmdletBinding()]
	[Alias('gmis')]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[string] $Path,

		[Parameter()]
		[switch]
		$Full,

		[Parameter()]
		[switch]
		$Raw
	)

	begin {
		Add-Type -Path ($PSScriptRoot + '\MediaInfoSharp.dll')
	}

	process {
		$Realpath = Convert-Path -LiteralPath $Path -ErrorAction Ignore
		if ([IO.File]::Exists($Realpath)) {
			$MediaInfo = [MediaInfoSharp]::new($Realpath)
			$Value = $MediaInfo.GetSummary($Full, $Raw)
			$MediaInfo.Dispose()
			Write-Output (("`r`n" + $Value) -split "`r`n")
		} else {
			Write-Output "`e[90m[`e[97mGet-MediaInfoSummary`e[90m][`e[31mError`e[90m]`e[0m : Invalid path argument given: `e[90m'`e[94m$Path`e[90m'`e[0m is not a file!"
		}
	}
}

function Clear-MediaInfoCache {
	[CmdletBinding(SupportsShouldProcess)]
	[Alias('clmic')]
	param()
	$CacheRoot = Join-Path ([IO.Path]::GetTempPath()) 'Get-MediaInfo-Cache'

	if ([IO.Directory]::Exists($CacheRoot)) {
		if ($PSCmdlet.ShouldProcess($CacheRoot, 'Remove MediaInfo Cache')) {
			Remove-Item -LiteralPath $CacheRoot -Recurse -Force -ErrorAction Stop
			Write-Output ("`e[90m[`e[97mClear-MediaInfoCache`e[90m][`e[32mSuccess`e[90m]`e[0m : The media info cache has been deleted from " +
				"`e[90m'`e[97m$([IO.Path]::GetTempPath())`e[90m'`e[0m!")
		}
	} else {
		Write-Output ("`e[90m[`e[97mClear-MediaInfoCache`e[90m][`e[94mInfo`e[90m]`e[0m : No media info cache has been found in " +
			"`e[90m'`e[97m$([IO.Path]::GetTempPath())`e[90m'`e[0m!")
	}
}
