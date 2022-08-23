param(
  [string] $SourceDirectory = "C:\Data\",

  [string] $ReplicaDirectory = "C:\Temp2\",

  [string] $LogFileLocation = "C:\Logs\"

)

# Creating Logs
function Log($LogInput)
{
   Write-Output $LogInput | Out-File -FilePath $LogFile -Append
   Write-Host $LogInput
}


Try
{
  $timestamp = Get-Date -Format "yyyyMMddTHHmmssffff"
  $LogFile = $LogFileLocation + $timestamp + ".txt"
  if ((Test-Path -Path $LogFileLocation) -ne $true)
  {
    New-Item -Path $LogFileLocation -ItemType Directory
    Log( "Log file directory did NOT exist. Log file directory created successfully. " + $LogFileLocation +"`n" )
  }

  Log("Starting directory sync now...")
  Log("Source Directory: "+ $SourceDirectory) 
  Log("Replica Directory: "+ $ReplicaDirectory) 
  Log("Log File Directory: "+ $LogFileLocation) 
  Log("`n")

  #verify source directory exists
  if (Test-Path -Path $SourceDirectory)
  {
    #Verify replica directory exists- if not Create new
    if ( (Test-Path -Path $ReplicaDirectory) -ne $true )
    {
      Log("Replica directory does NOT exist. Creating new one....")
      New-Item -Path $ReplicaDirectory -ItemType Directory
      Log(("Replica directory created successfully. " + $ReplicaDirectory ) )
      Log("`n")
    }

    #Empty source directory - exit and delete everything in target directory if exists
    if ( (Get-ChildItem $SourceDirectory | Measure-Object).Count -eq 0)
    {
      Log( "No files or subdirectories exist in source directory. Hence deleting every file from replica directory..." + $ReplicaDirectory )
      $FilesToDeleteFromReplicaDir = Get-ChildItem -Path ( $ReplicaDirectory ) -File -Recurse
      Log("`n")
      Log($FilesToDeleteFromReplicaDir )
      if (($FilesToDeleteFromReplicaDir| Measure-Object).Count -gt 0)
      {
        foreach ($file in $FilesToDeleteFromReplicaDir) { if(Test-Path $file.FullName) {Remove-Item $file.FullName}}
      }
      $FoldersTODeleteFromReplicaDir = Get-ChildItem -Recurse -Directory $ReplicaDirectory
      Log("`n")
      Log($FoldersTODeleteFromReplicaDir )
      foreach($folder in $FoldersTODeleteFromReplicaDir) 
      { if (Test-Path $folder.FullName)  
        {Remove-Item  $folder.FullName -Force -Recurse }
      }

      Log("`n")
      Log("Deleted above files from replica directory to match with source directory.")
      Log("`n")
      exit
    } 

    #Empty replica directory - copy everything in target directory and exit
    if ( (Get-ChildItem $ReplicaDirectory | Measure-Object).Count -eq 0)
    {
      Log( "No files or subdirectories exist in replica directory. Hence copying every file from source directory to " + $ReplicaDirectory )
      $CopyingFiles = Get-ChildItem -Path ( $SourceDirectory + "*" ) -Include * -Recurse
      Log($CopyingFiles)
      Copy-Item -Path ( $SourceDirectory + "*" ) -Destination $ReplicaDirectory -Force -Recurse -Container
      Log("Copied above files from souce directory.")
      Log("`n")
      exit
    } 

    #Compare source directory to target directory- files first
    Log("Getting details of Source directory....")
    $SourceFiles = Get-ChildItem –Path $SourceDirectory -Recurse

    foreach ($file in $SourceFiles)
    { 
      $file | Add-Member -MemberType NoteProperty -Name 'Path' -Value $file.FullName -PassThru
      $fileHash = Get-FileHash -Path $file.FullName -Verbose
      if ($fileHash -ne $null) 
      { $file | Add-Member -MemberType NoteProperty -Name 'Hash' -Value $fileHash 
        $file.Hash | Add-Member -NotePropertyMembers @{Name =$file.Name } -PassThru 
        $file.Hash| Add-Member -NotePropertyMembers @{RelativePath =  $file.FullName.substring($SourceDirectory.Length)}
      }
      
    }


    Log($SourceFiles)
    Log("`n")

    Log("Getting details of Replica directory....")
    $ReplicaFiles = Get-ChildItem –Path $ReplicaDirectory -Recurse

    foreach ($file in $ReplicaFiles)
    {
      $file | Add-Member -MemberType NoteProperty -Name 'Path' -Value $file.FullName
      
      $fileHash = Get-FileHash -Path $file.Path
      if ($fileHash -ne $null) 
      { $file | Add-Member -MemberType NoteProperty -Name 'Hash' -Value $fileHash 
        $file.Hash | Add-Member -NotePropertyMembers @{Name =$file.Name } -PassThru 
        $file.Hash| Add-Member -NotePropertyMembers @{RelativePath =  $file.FullName.substring($ReplicaDirectory.Length)}
      }
    }

    Log($ReplicaFiles)
    Log("`n")

    Log("Comparing source and replica directory....")
    $DifferenceInFiles = Compare-Object -ReferenceObject $SourceFiles.Hash  -DifferenceObject $ReplicaFiles.Hash -Property Hash,Name,RelativePath -PassThru

    #Compare source directory to target directory- for folders- specifically for accounting empty folders and subdirectories
    $SourceDirectoryCompareObject = Get-ChildItem -Recurse -Directory $SourceDirectory
    
    if ($SourceDirectoryCompareObject -eq $null)
     {
        $SourceDirectoryCompareObject += Get-Item $SourceDirectory

     }
    foreach ($subdirectory in $SourceDirectoryCompareObject)
    {
          $Length = $SourceDirectory.length
          $subdirectory | Add-Member -MemberType NoteProperty -Name 'RelativePath' -Value $subdirectory.FullName.substring($Length)
    }
    

    $ReplicaDirectoryCompareObject = Get-ChildItem -Recurse -Directory $ReplicaDirectory
    if ($ReplicaDirectoryCompareObject -eq $null) {$ReplicaDirectoryCompareObject += Get-Item $ReplicaDirectory}
    foreach ($subdirectory in $ReplicaDirectoryCompareObject)
    {
      $Length = $ReplicaDirectory.length
      $subdirectory | Add-Member -MemberType NoteProperty -Name 'RelativePath' -Value $subdirectory.FullName.substring($Length)
    }
    $DifferenceInDirectories = Compare $SourceDirectoryCompareObject $ReplicaDirectoryCompareObject -Property RelativePath
    Log($DifferenceInFiles)
    Log("`n")
    Log($DifferenceInDirectories)
    Log("`n")

    if (($DifferenceInFiles -eq $null) -and ($DifferenceInDirectories -eq $null ))
    {
      Log("Source directory and replica directory already are in sync.")
      exit
    }

     #If files are deleted from source folder/does not exist at source folder, delete them from replica folder
    Log("Deleting below files from replica folder which are not present, changed or no longer exist in source directory: ")

    $ReferenceFilesToDelete = $DifferenceInFiles | where {$_.SideIndicator -eq "=>"}
    $FilesToDelete = @()

    foreach ($i in $ReferenceFilesToDelete)
    {
      foreach ($k in $ReplicaFiles)
      {
       if (($k.Hash.Hash -eq $i.Hash)  -and ($k.Hash.Name -eq $i.Name) -and ($k.Hash.RelativePath -eq $i.RelativePath) )
        {
          $l = $k.Hash.Path
          $FilesToDelete += $l 
        }
      }
    }

    $FoldersToDelete = $DifferenceInDirectories | where {$_.SideIndicator -eq "=>"} | %{if($_.FullName -ne $null) {$_.FullName} else {Join-Path $ReplicaDirectory $_.RelativePath}}

    Log($FilesToDelete)
    Log($FoldersToDelete)
    Log("`n")
    if (($FilesToDelete | Measure-Object).Count -gt 0) 
    {
        foreach ($file in $FilesToDelete) { if(Test-Path $file) {Remove-Item $file}}
    }
    foreach ($folder in $FoldersToDelete)
    { 
        if (Test-Path $folder)  
        {Remove-Item $folder -Force -Recurse }
    }
    
    #If files are added or updated, copy to replica folder
    Log("Copying below files over to replica folder: ")
    $ReferenceFilesToCopy = $DifferenceInFiles | where {$_.SideIndicator -eq "<="}
    $FilesToCopy = @()

    foreach ($i in $ReferenceFilesToCopy)
    {
      foreach ($k in $SourceFiles)
      {
       if (($k.Hash.Hash -eq $i.Hash) -and ($k.Hash.Name -eq $i.Name) -and ($k.Hash.RelativePath -eq $i.RelativePath))
       {
        $l = $k.Hash.Path
        $FilesToCopy += $l 
       }
      }
    }

    $FoldersToCopy = $DifferenceInDirectories | where {$_.SideIndicator -eq "<="} | %{$_.RelativePath}

    Log($FilesToCopy)
    Log("`n")
    Log($FoldersToCopy)
    Log("`n")
      
    foreach ($folder in $FoldersToCopy)
    {
      $PathSplit = $folder.Split('\')
      $PathToCheck = $ReplicaDirectory

      for ($i=0; $i -lt $PathSplit.Length; $i++)
      {
        $PathToCheck += "\" +$PathSplit[$i]
        if ((Test-Path $PathToCheck ) -ne $true)
        { New-Item -ItemType directory -Path $PathToCheck -Force }
      }
    }


    foreach ($file in $FilesToCopy)
    {
      $PathSplit = $file.Replace($SourceDirectory, "").ToString().Split('\')
      $PathToCheck = $ReplicaDirectory

      for ($i=0; $i -lt $PathSplit.Length-1; $i++)
      {
        $PathToCheck += "\" + $PathSplit[$i]
        if ((Test-Path $PathToCheck ) -ne $true)
        { New-Item -ItemType directory -Path $PathToCheck -Force }
      }
      $CorrectPath = Join-Path $ReplicaDirectory ($file.Replace($SourceDirectory, "").ToString())
      Copy-Item -Path $file -Destination $CorrectPath -Force -Container
    }

    Log("Done synchronizing source directory " + $SourceDirectory  + " to replica directory " + $ReplicaDirectory )
  }
  else 
  {
    Log("Source directory does NOT exist.")
  }
}
Catch 
{
  Log("Error occured....`n")
  Log($_.Exception)
  Log("`n")
}
Finally 
{
  Log( "Created and saved logfile: " + $LogFile )
  Log("Exiting...")
} 
