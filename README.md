Develop a PowerShell script that synchronizes two directories: the source directory and the replica directory. The purpose of the script is to match the contents of the replica directory with the contents of the source directory.

Requirements: 

Synchronization must be one-way: after the synchronization process is completed, the contents of the replica directory must exactly match the contents of the source directory;
Operations of creating/copying/deleting objects should be logged in a file and written to the console; 
Paths to directories and the path to the log file must be specified as parameters when running the script; 
Do not use robocopy and similar utilities;
Publish the result of your work on GitHub.
