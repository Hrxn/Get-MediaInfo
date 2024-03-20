@{
	RootModule            = 'Get-MediaInfo.psm1'
	ModuleVersion         = '3.8.0'
	GUID                  = '86639e26-2698-42ec-b7f1-c66daca2eb78'
	Author                = 'Original by Frank Skare (stax76) / Fork by HRXN (Hrxn)'
	CompanyName           = 'Frank Skare (stax76)'
	Copyright             = '(c) 2020-2021 Frank Skare (stax76). All rights reserved.'
	Description           = 'MediaInfo Integration Module for PowerShell'
	PowerShellVersion     = '7.2'
	ProcessorArchitecture = 'Amd64'
	FunctionsToExport     = @('Get-MediaInfo', 'Get-MediaInfoValue', 'Get-MediaInfoSummary', 'Clear-MediaInfoCache')
	VariablesToExport     = @()
	CmdletsToExport       = @()
	AliasesToExport       = @('gmi', 'gmiv', 'gmis', 'clmic')
	PrivateData           = @{
		PSData = @{
			Tags       = @('Mediainfo', 'Multimedia', 'Media', 'Metadata', 'Video', 'Audio', 'Mediadata')
			ProjectUri = 'https://github.com/Hrxn/Get-MediaInfo'
		}
	}
}
