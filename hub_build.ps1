Set-StrictMode -version latest;
$ErrorActionPreference = "Stop";
$ORIGINAL_WORKING_DIR = Get-Location;
$WorkingDir = split-path -parent $MyInvocation.MyCommand.Definition;
$CefDockerDir = Join-Path $WorkingDir "../CefSharpDockerfiles"

try{
	. (Join-Path $CefDockerDir 'functions.ps1')
	Set-Location $CefDockerDir
	Copy (Join-Path $WorkingDir "our_versions.ps1") "versions.ps1"
	Copy (Join-Path $WorkingDir "our_Dockerfile_vs") "Dockerfile_vs"

	#frees up a good bit of spce on the c drive where docker runs
	$ToDelete = @("C:/Program Files/Microsoft Visual Studio", "C:/Program Files (x86)/Android", "C:/Program Files (x86)/Windows Kits", "C:/Program Files (x86)/Microsoft SDKs", "C:/Microsoft/AndroidNDK")
	$ToDelete | foreach { Remove-Item -Recurse -Force $_ }


	& "$CefDockerDir\build.ps1" -NoMemoryWarn

	Write-Host -ForegroundColor Green Build completed successfully of test checkout!
}catch{
	WriteException $_;
}
Set-Location $ORIGINAL_WORKING_DIR;	