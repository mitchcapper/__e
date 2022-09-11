[CmdletBinding()]
Param(
	[Switch] $NoSkip,
	[Switch] $NoMemoryWarn,
	[Switch] $JustToCEFSource,
	[Switch] $JustToVSCache,
	[Switch] $NoVS2019PatchCopy
)
Install-Module -Name Use-RawPipeline -Scope CurrentUser -AcceptLicense -AllowPrerelease -SkipPublisherCheck -Force;

$WorkingDir = split-path -parent $MyInvocation.MyCommand.Definition;
. (Join-Path $WorkingDir 'functions.ps1')
#Always read the source file first incase of a new variable.
. (Join-Path $WorkingDir "versions_src.ps1")
#user overrides
if (Test-Path ./versions.ps1 -PathType Leaf){
	. (Join-Path $WorkingDir "versions.ps1")
}
Set-StrictMode -version latest;
$ErrorActionPreference = "Stop";
$ORIGINAL_WORKING_DIR = Get-Location;
try{
	Set-Location $WorkingDir
if (-not $VAR_CEF_BUILD_MOUNT_VOL_NAME){
	$VAR_CEF_BUILD_MOUNT_VOL_NAME = "cefbuild_" + -join ((97..122) | Get-Random -Count 5 | % {[char]$_});
}


Write-Host -Foreground Green "Will use local volume/build name: '$VAR_CEF_BUILD_MOUNT_VOL_NAME' if not empty will resume cef build in there set `$VAR_CEF_BUILD_MOUNT_VOL_NAME in versions.ps1 to this value to resume"

$redirect_output = $false;
$PSSenderInfo = Get-Variable -name "PSSenderInfo" -ErrorAction SilentlyContinue;
if ($PSSenderInfo){
	$redirect_output = $true;
	Write-Host -Foreground Yellow "Warning when running this build command in a remote powershell session you will not see realtime output generated by commands run.  This is due to a limitation in remote powershell.  You can work around this by running the build.ps1 using remote desktop instead.  In general it is only helpful to see the output if there is an error.  The stdout and stderr will be captured and printed for remote sessions but only after a command finishes."
}
$global:PERF_FILE = Join-Path $WorkingDir "perf.log";
if ((Get-MpPreference).DisableRealtimeMonitoring -eq $false){ #as admin you can disable with: Set-MpPreference -DisableRealtimeMonitoring $true
	Write-Host Warning, windows defender is enabled it will slow things down. -Foreground Red 
}
if (! $NoMemoryWarn){
	$page_files = Get-CimInstance Win32_PageFileSetting;
	$os = Get-Ciminstance Win32_OperatingSystem;
	$min_gigs = 27;
	$warning = "linking may take around $min_gigs during linking";
	if ($VAR_DUAL_BUILD -eq "1"){
		$warning="dual build mode is enabled and may use 50+ GB if both releases link at once.";
		$min_gigs = 50;
	}
	if (($os.FreePhysicalMemory/1mb + $os.FreeSpaceInPagingFiles/1mb) -lt $min_gigs) { #if the memory isn't yet avail with the page files and they have a set size lets try to compute it that way
		$total_memory_gb = $os.FreePhysicalMemory/1mb;
		foreach ($file in $page_files){
			$total_memory_gb += $file.MaximumSize/1kb; #is zero if system managed, then we really don't know how big it could be.
		}
		if ($total_memory_gb -lt $min_gigs){
			if (! (confirm("Warning $warning.  Your machine may not have enough memory, make sure your page files are working and can grow to allow it. (Disable this warning with -NoMemoryWarn flag). Do you want to proceed?"))){
				exit 1;
			}

		}
	}
}
if (! $NoVS2019PatchCopy -and $VAR_CHROME_BRANCH -lt 4103 ){
	if ( (Test-Path "cef_patch_find_vs2019_tools.diff") -eq $false){
		Copy-Item sample_patches/cef_patch_find_vs2019_tools.diff -Destination .
	}
}

if (! (Test-Path -Path "zstd.exe" -PathType Leaf) ) {
	#libarchive
	Invoke-WebRequest 'https://page.ghfs.workers.dev/archive.dll' -OutFile 'archive.dll';
	Invoke-WebRequest 'https://page.ghfs.workers.dev/bsdtar.exe' -OutFile 'bsdtar.exe';
	Invoke-WebRequest 'https://page.ghfs.workers.dev/zstd.exe' -OutFile 'zstd.exe';

}

echo *.zip | out .dockerignore
TimerNow("Starting");
RunProc -proc "docker" -redirect_output:$redirect_output -opts "pull $VAR_BASE_DOCKER_FILE";
TimerNow("Pull base file");
RunProc -proc "docker" -redirect_output:$redirect_output -opts "build $VAR_HYPERV_MEMORY_ADD --build-arg BASE_DOCKER_FILE=`"$VAR_BASE_DOCKER_FILE`" -f Dockerfile_vs --cache-from vs -t vs ."
TimerNow("VSBuild");
if ($JustToVSCache) {
	run docker save vs | run zstd "-o" "c:/temp/vs.tar.zstd" | 2ps

	TimerNow("Docker Export VS size: " + ((Get-Item "c:/temp/vs.tar.zstd").length/1GB).ToString("0.0 GB"));
	exit 0
}
$VAR_CEF_SAVE_SOURCES = "save";

if ($VAR_CEF_USE_BINARY_PATH -and $VAR_CEF_USE_BINARY_PATH -ne ""){
	$docker_file_name="Dockerfile_cef_create_from_binaries";

	$good_hash = Get-FileHash $docker_file_name;
	$new_path = Join-Path $VAR_CEF_USE_BINARY_PATH $docker_file_name;
	if ( (Test-Path $new_path -PathType Leaf) -eq $false -or (Get-FileHash $new_path).Hash -ne $good_hash.Hash){
		Copy $docker_file_name $VAR_CEF_USE_BINARY_PATH;
	}
	Set-Location -Path $VAR_CEF_USE_BINARY_PATH;
	RunProc -proc "docker" -redirect_output:$redirect_output -opts "build $VAR_HYPERV_MEMORY_ADD --build-arg BINARY_EXT=`"$VAR_CEF_BINARY_EXT`" -f $docker_file_name --cache-from vs --cache-from cef -t cef ."
	Set-Location $ORIGINAL_WORKING_DIR;
} else {
	RunProc -proc "docker" -redirect_output:$redirect_output -opts "build $VAR_HYPERV_MEMORY_ADD --build-arg CEF_SAVE_SOURCES=`"$VAR_CEF_SAVE_SOURCES`" --build-arg ARCHES=`"$VAR_BUILD_ARCHES`" --build-arg BINARY_EXT=`"$VAR_CEF_BINARY_EXT`" --build-arg GN_ARGUMENTS=`"$VAR_GN_ARGUMENTS`" --build-arg DUAL_BUILD=`"$VAR_DUAL_BUILD`" --build-arg GN_DEFINES=`"$VAR_GN_DEFINES`" --build-arg GYP_DEFINES=`"$VAR_GYP_DEFINES`" --build-arg CHROME_BRANCH=`"$VAR_CHROME_BRANCH`" -f Dockerfile_cef -t cef_build_env ."
	$exit_code = RunProc -errok -proc "docker" -opts "tag i_$($VAR_CEF_BUILD_MOUNT_VOL_NAME) cef"; #if this fails we know it didn't build correctly and to continue
	if ($exit_code -ne 0){
		RunProc -errok -proc "docker" -opts "rm c_$($VAR_CEF_BUILD_MOUNT_VOL_NAME)_tmp"
		$JustToCEFSourceAdd = "";
		if ($JustToCEFSource){
			$JustToCEFSourceAdd = "-e JustToCEFSource=save";
		}
		RunProc -proc "docker" -redirect_output:$redirect_output -opts "run $VAR_HYPERV_MEMORY_ADD $JustToCEFSourceAdd -v $($VAR_CEF_BUILD_MOUNT_VOL_NAME):C:/code/chromium_git --name c_$($VAR_CEF_BUILD_MOUNT_VOL_NAME)_tmp cef_build_env"
		if ($JustToCEFSource){
			RunProc -proc "docker" -redirect_output:$redirect_output -opts "cp c_$($VAR_CEF_BUILD_MOUNT_VOL_NAME)_tmp:/code/chromium_git/src.zstd c:/temp/src.zstd";
			exit 0
		}
		$exit_code = RunProc -errok -proc "docker" -opts "commit c_$($VAR_CEF_BUILD_MOUNT_VOL_NAME)_tmp i_$($VAR_CEF_BUILD_MOUNT_VOL_NAME)";
		$exit_code = RunProc -errok -proc "docker" -opts "tag i_$($VAR_CEF_BUILD_MOUNT_VOL_NAME) cef";
	}
}
TimerNow("CEF Build");
if (! $VAR_CEF_BUILD_ONLY){
	RunProc -proc "docker" -redirect_output:$redirect_output -opts "build $VAR_HYPERV_MEMORY_ADD --build-arg ARCHES=`"$VAR_BUILD_ARCHES`" --build-arg BINARY_EXT=`"$VAR_CEF_BINARY_EXT`"  --build-arg CEFSHARP_VERSION=`"$VAR_CEFSHARP_VERSION`" -f Dockerfile_cef_binary -t cef_binary ."
	TimerNow("CEF Binary compile");
	RunProc -proc "docker" -redirect_output:$redirect_output -opts "build $VAR_HYPERV_MEMORY_ADD --build-arg CEFSHARP_BRANCH=`"$VAR_CEFSHARP_BRANCH`" --build-arg CEFSHARP_VERSION=`"$VAR_CEFSHARP_VERSION`" --build-arg CEF_VERSION_STR=`"$VAR_CEF_VERSION_STR`"  --build-arg ARCHES=`"$VAR_BUILD_ARCHES`" --build-arg CHROME_BRANCH=`"$VAR_CHROME_BRANCH`" -f Dockerfile_cefsharp -t cefsharp ."
	TimerNow("CEFSharp compile");
	RunProc -proc "docker" -opts "rm cefsharp" -errok;
	Start-Sleep -s 6; #sometimes we are too fast, file in use error
	RunProc -proc "docker" -redirect_output:$redirect_output -opts "run --name cefsharp cefsharp cmd /C echo CopyVer"
	RunProc -proc "docker" -redirect_output:$redirect_output -opts "cp cefsharp:/packages_cefsharp.zip ."
	TimerNow("CEFSharp copy files locally");
}else{
	docker rm cef;
	Start-Sleep -s 3; #sometimes we are too fast, file in use error
	RunProc -proc "docker" -redirect_output:$redirect_output -opts "run --name cef cef powershell Compress-Archive -Path C:/code/binaries/*.zip -CompressionLevel Fastest -DestinationPath /packages_cef"
	RunProc -proc "docker" -redirect_output:$redirect_output -opts "cp cef:/packages_cef.zip ."
	
	TimerNow("CEF copy files locally");
}
if ($VAR_REMOVE_VOLUME_ON_SUCCESSFUL_BUILD){
	RunProc --errok -proc "docker" -opts "volumes rm $VAR_CEF_BUILD_MOUNT_VOL_NAME";
}
Write-Host -ForegroundColor Green Build completed successfully! See $global:PERF_FILE for timing for each step.
}catch{
	WriteException $_;
	Set-Location $ORIGINAL_WORKING_DIR;
	exit 1;
}
Set-Location $ORIGINAL_WORKING_DIR;