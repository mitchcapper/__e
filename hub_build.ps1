Set-StrictMode -version latest;
$ErrorActionPreference = "Stop";
$ORIGINAL_WORKING_DIR = Get-Location;
$WorkingDir = split-path -parent $MyInvocation.MyCommand.Definition;


try{
	. (Join-Path $WorkingDir "../CefSharpDockerfiles" 'functions.ps1')


	Write-Host -ForegroundColor Green Build completed successfully of test checkout!
}catch{
	WriteException $_;
}
Set-Location $ORIGINAL_WORKING_DIR;	