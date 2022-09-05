Set-StrictMode -version latest;
$ErrorActionPreference = "Stop";
$ORIGINAL_WORKING_DIR = Get-Location;
$WorkingDir = split-path -parent $MyInvocation.MyCommand.Definition;
$CefDockerDir = Join-Path $WorkingDir "../CefSharpDockerfiles"

try{
	. (Join-Path $CefDockerDir 'functions.ps1')



	& "$CefDockerDir\build.ps1" -NoMemoryWarn

	Write-Host -ForegroundColor Green Build completed successfully of test checkout!
}catch{
	WriteException $_;
}
Set-Location $ORIGINAL_WORKING_DIR;	