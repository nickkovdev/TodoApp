$extractedpath = $OctopusParameters[“Octopus.Action.Package[TodoGCP].ExtractedPath”]
Write-Host “Extracted Path: $extractedpath”
$content = Get-Content -Path “$extractedpath\”;
Write-Host “Content: $content”
$serviceAccountJson = ‘#{MyServiceAccountKey}’
Write-Host “Serivce Account: $serviceAccountJson”
$serviceAccountJsonFilePath = “$extractedpath\serviceAccount.json”
Set-Content -Path “$serviceAccountJsonFilePath” -Value “$serviceAccountJson”
$gcloudExtractedPath = $OctopusParameters[“Octopus.Action.Package[TodoGCP].ExtractedPath”]
Write-Host “Extracted GCP Path: $gcloudExtractedPath”

$CMD = “$gcloudExtractedPath\google-cloud-sdk\bin\gcloud.cmd”
$arg1 = “auth”
$arg2 = “activate-service-account”
$arg3 = “ — key-file=$serviceAccountJsonFilePath”
& $CMD $arg1 $arg2 $arg3

$appEngineServiceVersion = $OctopusParameters[“Octopus.Action.Package[TodoGCP].PackageVersion”]

$arg1 = “app”
$arg2 = “deploy”
$arg3 = “ — project=#{MyGCPProjectName}”
$arg4 = “ — version=$appEngineServiceVersion”
$arg5 = “ — quiet”
Set-Location $extractedpath
& $CMD $arg1 $arg2 $arg3 $arg4 $arg5