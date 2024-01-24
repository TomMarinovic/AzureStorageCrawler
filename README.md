# AzureStorageCrawler
Azure Storage Account Crawler

This is a simple Azure Storage Account Crawler searching for open Public folders, written in Powershell

To use you will have to install the Powershell Modules AZ and MSOnline according to the Microsoft guide. I recommed using Powershell Version 5.1

This script works by checking for the accounts in the tragets.txt and then, if they exist, for the the folders in the permutaions.txt (examples of both files are provided modifey as need be). Should any of the permutations be publicly avaiable the script will print the download url for all files in folder as well as subfolders.

