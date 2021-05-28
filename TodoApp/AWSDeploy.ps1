<#
.DESCRIPTION Waits for the given environment to finish any processing
.PARAMETER application The name of the Beanstalk application
.PARAMETER environment The name of the Beanstalk environment
#>
function Wait-ForEnvironmentToBeReady ($application, $environment) {
    do {
      $result = aws elasticbeanstalk describe-environments `
          --environment-names $environment `
          --application-name $application `
          --output json |
          ConvertFrom-Json |
          Select-Object -ExpandProperty Environments |
          Select-Object -First 1

      if ($null -eq $result) {
          throw "Could not find the environment $environment in the application $application"
      }

      Write-Host "Environment $environment is $($result.Status)"
      Start-Sleep 10
    } while (-not ($result.Status -in @("Ready", "Terminated")))
  }

  <#
  .DESCRIPTION Creates a new application version
  .PARAMETER application The name of the Beanstalk application
  .PARAMETER version The name of the Beanstalk application version
  .PARAMETER s3Bucket The S3 bucket that holds the application code
  .PARAMETER s3Key The S3 file of the application code
  #>
  function New-ApplicationVersion($application, $version, $s3Bucket, $s3Key) {
    Write-Host "Creating application version $version"
    aws elasticbeanstalk create-application-version `
        --application-name $application `
        --version-label $version `
        --source-bundle S3Bucket="s3://elasticbeanstalk-eu-central-1-935901513907",S3Key="$s3Key" |
        Out-Null

  }

  <#
  .DESCRIPTION Uploads a file to S3
  .PARAMETER file The file to upload
  .PARAMETER s3Bucket The S3 bucket that holds the application code
  .PARAMETER s3Key The S3 file of the application code
  #>
  function Add-File($file, $s3Bucket, $s3Key) {
    Write-Host "Uploading File"
    aws s3 cp $file "s3://elasticbeanstalk-eu-central-1-935901513907/$s3Key" | Out-Null
  }

  <#
  .DESCRIPTION Updates a Beanstalk environment with the supplied application version
  .PARAMETER application The name of the Beanstalk application
  .PARAMETER environment The name of the Beanstalk environment
  .PARAMETER version The name of the Beanstalk application version
  #>
  function Update-Environment($application, $environment, $version) {
    Write-Host "Updating Environment $environment to $version"
    aws elasticbeanstalk update-environment `
        --application-name $application `
        --environment-name "Todoaws-env" `
        --version-label $version |
        Out-Null
  }

  function New-ManifestFile($name, $file) {
      Set-Content -Path "aws-windows-deployment-manifest.json" -Value @"
      {
        "manifestVersion": 1,
        "deployments": {
            "aspNetCoreWeb": [
            {
                "name": "$name",
                "parameters": {
                    "appBundle": "$file",
                    "iisPath": "/",
                    "iisWebSite": "Default Web Site"
                }
            }
            ]
        }
    }
"@
  }

  $VersionLabel = $OctopusParameters["Octopus.Action.Package[TodoAppAWS].PackageId"] +
      "." +
      $OctopusParameters["Octopus.Action.Package[TodoAppAWS].PackageVersion"] +
      "." +
      $OctopusParameters["Octopus.Deployment.Id"]

  New-ManifestFile "random-quotes" "site.zip"

  # Compress the extracted DotNET application code
  Compress-Archive `
      -Path "$($OctopusParameters["Octopus.Action.Package[TodoAppAWS].ExtractedPath"])\*" `
      -DestinationPath "site.zip"

  # Compress the application code with the manifest file to create the Beanstalk deployment    
  Compress-Archive `
      -Path "site.zip", "aws-windows-deployment-manifest.json" `
      -DestinationPath "$VersionLabel.zip"

  # Upload the Beanstalk deployment to S3    
  Add-File "$VersionLabel.zip" $BucketName "$VersionLabel.zip"

  # Use the new file in S3 to create a Beanstalk application version
  New-ApplicationVersion $Application $VersionLabel $BucketName "$VersionLabel.zip"

  # Wait for any pending changes to the environment to finish
  Wait-ForEnvironmentToBeReady  $Application $Environment

  # Deploy the application version to the environment
  Update-Environment $Application $Environment $VersionLabel

  # Wait for the new deployment to finish
  Wait-ForEnvironmentToBeReady  $Application $Environment