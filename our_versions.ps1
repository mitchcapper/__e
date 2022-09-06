$VAR_CHROME_BRANCH="5195";
$VAR_CEFSHARP_VERSION="105.0.98";
$VAR_CEFSHARP_BRANCH="master";
$VAR_BASE_DOCKER_FILE="mcr.microsoft.com/windows/servercore:ltsc2022"; #microsoft/dotnet-framework:4.7.1-windowsservercore-1709   listings found at https://hub.docker.com/_/microsoft-windows-servercore
$VAR_DUAL_BUILD="0"; #set to 1 to build x86 and x64 together, mainly to speed up linking which is single threaded, note may need excess ram.
$VAR_GN_DEFINES="is_official_build=true proprietary_codecs=true ffmpeg_branding=Chrome";
$VAR_GYP_DEFINES="";
$VAR_CEF_BUILD_MOUNT_VOL_NAME="cefbuild_rnnda"; #if this is not set but $VAR_USE_DOCKER_LOCAL_MOUNT_LOCATION is then this will be a randomly generated string, this is also the final cef build commit name so if an image exists with this name it is assumed the build was successful, no spaces allowed
$VAR_REMOVE_VOLUME_ON_SUCCESSFUL_BUILD=$false;#if set to valse will leave the build volume alone when done, true will remove it, primary contains CEF sources.
$VAR_CEF_BUILD_ONLY=$false;#Only build CEF do not build cefsharp or the cef-binary.
$VAR_CEF_USE_BINARY_PATH="";#useful for only building cef-binary and cefsharp from existing CEF binaries. Folder should contain the binary zip files from a cef build
$VAR_CEF_BINARY_EXT="zip"; #Can be zip,tar.bz2, 7z Generally do not change this off of Zip unless you are supplying your own binaries using $VAR_CEF_USE_BINARY_PATH above, and they have a different extension, will try to work with the other formats however
$VAR_CEF_SAVE_SOURCES="0";
$VAR_CEF_VERSION_STR="auto"; #can set to "3.3239.1723" or similar if you have multiple binaries that Docker_cefsharp might find
$VAR_HYPERV_MEMORY_ADD="--memory=7g --isolation=process"; #only matters if using HyperV, Note your swap file alone must be this big or able to grow to be this big, 30G is fairly safe for single build will need 60G for dual build.
$VAR_BUILD_ARCHES="x64";