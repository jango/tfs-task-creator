# Default parameters - do a dry run by default.
Param(
  [switch] $help = $false,
  [bool] $dry_run = $true,
  [string] $config = "$PSScriptRoot\config.sample.xml"
)

# Enable strict mode for the current scope.
Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"

### Replaces variables in a given string with values.
### WORK_ITEM_ID - TFS ID of the top most item.
### PARENT_ITEM_ID - TFS ID of the immediate parent.
function Replace_Placeholders
{
    param( [string]$str, [int]$WORK_ITEM_ID,
           [int]$PARENT_ITEM_ID )
    
    $s = ($str) -replace "{{WORK_ITEM_ID}}", [int]$WORK_ITEM_ID

    if ($PARENT_ITEM_ID -eq 0) {
        ($s) -replace "{{PARENT_ITEM_ID}}", "<ID>"
    } else {
        ($s) -replace "{{PARENT_ITEM_ID}}", [int]$PARENT_ITEM_ID
    }
}

# Clear output pane.
clear

$version = "0.1"

if ([switch]$help){
    write-host "Hello!`nI am a friendly TFS script, I can create a set of standard tasks for you."
    write-host "- I use config.xml in the directory where I live by default, but you can specify"
    write-host "a different file by adding -config, switch like this: -config 'C:\config.xml'"
    write-host "- I always do a dry-run first and once you are happy with the result, use -dry_run `$false"
    write-host "switch to commit change to TFS."
    exit
}

if ($dry_run) {
    write-host("******DRY RUN, NO CHANGES WILL BE SAVED. RUN WITH -dry_run `$false TO COMMIT CHANGES******")
}

try {
    # Loads Windows PowerShell snap-in if not already loaded
    if ((Get-PSSnapin -Name Microsoft.TeamFoundation.PowerShell -ErrorAction SilentlyContinue) -eq $null )
    {
        Add-PSSnapin Microsoft.TeamFoundation.PowerShell
    }

    $binpath   = "C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\ReferenceAssemblies\v2.0"
    Add-Type -path "$binpath\Microsoft.TeamFoundation.Client.dll"
    Add-Type -Path "$binpath\Microsoft.TeamFoundation.WorkItemTracking.Client.dll"

} catch {
    write-host "Error adding TFS snap-ins; you may need to install TFS 2013 power tools with cmdlets option; script won't run."
    $Error[0]
    exit
}

# Import email settings from config file
try {
    [xml]$ConfigFile = Get-Content $config
} catch {
    write-host "Unable to load the configuration file:"
    write-host
    $Error[0]
    exit
}


# TFS Server address.
[string] $tfsServer = $ConfigFile.settings.tfs_server
[string] $tfsProject = $ConfigFile.settings.tfs_project

try {
    write-host ("Connecting to:")
    write-host  ("TFS Server: {0}" -f $tfsServer)
    write-host  ("TFS Project: {0}" -f $tfsProject)
    write-host

    # Get an instance of TfsTeamProjectCollection
    $tfs=get-tfsserver $tfsServer

    # Get an instance of WorkItemStore
    $WIT = $tfs.GetService([Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore])
} catch {
    write-host "Unable to connect to the specified project:"
    write-host
    $Error[0]
    exit
}

# If not a dry run, ask user to confirm.
if (!$dry_run){

    $prompt = read-host("Create tasks? Y/y to continue, any other key to cancel")

    write-host

    # If not, exit.
    if ($prompt.ToLower() -ne "y"){
        exit
    }

} 

$work_items_count = 0
$items_created_count = 0
$errors_count = 0


$items = @()

# Expand iteration queries to individual item IDs.
foreach ($parent_item in $ConfigFile.settings.parent_items.parent_item){
    if ($parent_item.HasAttribute("ID")){
        $items += $parent_item.ID
    }

    if ($parent_item.HasAttribute("Iteration")){
        try {
            foreach($item in $WIT.Query("SELECT * FROM WorkItems WHERE [System.WorkItemType] = 'User Story' AND [System.IterationPath] UNDER '" + $parent_item.Iteration + "'")){
                $items += $item.Id
            }
        } catch {
            write-host("***ERROR*** Iteration '{0}' was not found" -f $parent_item.Iteration)
            write-host
            $errors_count++;
        }
    }
}

# Loop through all Work Items for which tasks are to be created.
foreach ($parent_item in $items)
{

    $work_items_count++

    # Check that the provided ID is an integer.
    if(![bool]($parent_item -as [int])){
        write-host ("Requested Work Item ID {0} is not an integer ಠ_ಠ, skipping." -f $parent_item)
        $errors_count++
        continue
    }
    
    # Check that the item exists.
    [int] $workItemID = $parent_item -as [int];
    try {
        $workItem = $WIT.GetWorkItem($workItemID);

    } catch {
        write-host ("Requested Work Item {0} is not in TFS ಠ_ಠ, skipping." -f $workItemID)
        $errors_count++
        continue;
    }

    write-host ("Work Item {0}:" -f $workItemID)
 
    $workItem_Title = $workItem.Title;
    $workItem_AreaId = $workItem.AreaId;
    $workItem_AreaPath = $workItem.AreaPath;
    $workItem_IterationId = $workItem.IterationId;
    $workItem_IterationPath = $workItem.IterationPath;

    write-host ("`tWork Item Title: {0}" -f $workItem_Title)
    write-host ("`tArea Path:       {0}" -f $workItem_AreaPath)
    write-host ("`tIteration Path:  {0}" -f $workItem_IterationPath)
    write-host ("`tTasks: ")

    $linkType = $WIT.WorkItemLinkTypes[[Microsoft.TeamFoundation.WorkItemTracking.Client.CoreLinkTypeReferenceNames]::Hierarchy]
    
    # Tasks - first level.
    foreach ($task in $ConfigFile.settings.tasks.task) {
        $items_created_count++

        if ($dry_run){
            write-host ("`t`t- '{0}'" -f (Replace_Placeholders -str $task.title -WORK_ITEM_ID $workItemID -PARENT_ITEM_ID $workItemID))
        }

        $new_task = $WIT.projects[$tfsProject].WorkItemTypes["Task"].NewWorkItem()
        $new_task.Title = (Replace_Placeholders -str $task.title -WORK_ITEM_ID $workItemID -PARENT_ITEM_ID $workItemID)
        try {
            $new_task.IterationId = $workItem_IterationId;
            $new_task.AreaId = $workItem_AreaId;
        } catch {
            write-host("`t`t`t***ERROR*** Project mismatch: creating items in project '{0}' but work item {1} does belongs to '{2}' project. Remove the work item from the list or change the project." -f  $ConfigFile.settings.tfs_project, $workItemID, $workItem.Project.Name)
            $errors_count++
        }

        if ($task.HasAttribute("assignee")){
            $new_task.Fields["Assigned To"].Value = $task.assignee
        }

        if ($task.HasAttribute("history")){
            $new_task.History = $task.history
        }

        # Link to the parent.
        $link = new-object Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemLink($linkType.ReverseEnd, $workItemID) 
        $new_task.WorkItemLinks.Add($link) >$null
        
        $invalid_fields = $new_task.validate();

        # http://msdn.microsoft.com/en-us/library/microsoft.teamfoundation.workitemtracking.client.fieldstatus.aspx
        if ($invalid_fields.Count -gt 0){
            foreach ($field in $invalid_fields){
                write-host("`t`t`t***ERROR*** '{0}': {1}. Field value: '{2}'" -f $field.Name, $field.Status, $field.Value)
                $errors_count++
            }

            if (!$dry_run) {
                break;
            }
        }
        
        if (!$dry_run) {
            $new_task.save()
            write-host ("`t`t- ({0}) '{1}'" -f $new_task.Id, (Replace_Placeholders -str $task.title -WORK_ITEM_ID $workItemID -PARENT_ITEM_ID $workItemID))
        }

        
        if ($task.HasChildNodes){
            # Tasks - second level.
            foreach ($subtask in $task.tasks.task) {
                $items_created_count++

                if ($dry_run) {
                    write-host ("`t`t`t- '{0}'" -f (Replace_Placeholders -str $subtask.title -WORK_ITEM_ID $workItemID -PARENT_ITEM_ID 0))
                }

                $new_subtask= $WIT.projects[$tfsProject].WorkItemTypes["Task"].NewWorkItem()
                $new_subtask.Title = (Replace_Placeholders -str $subtask.title -WORK_ITEM_ID $workItemID -PARENT_ITEM_ID $new_task.Id)

                try {
                    $new_subtask.IterationId = $workItem_IterationId;
                    $new_subtask.AreaId = $workItem_AreaId;
                } catch {
                    write-host("`t`t`t***ERROR*** Project mismatch: creating items in project '{0}' but work item {1} does belongs to '{2}' project. Remove the work item from the list or change the project." -f  $ConfigFile.settings.tfs_project, $workItemID, $workItem.Project.Name)
                    $errors_count++
                }


                if ($subtask.HasAttribute("assignee")){
                    $new_subtask.Fields["Assigned To"].Value = $subtask.assignee
                }

                if ($subtask.HasAttribute("history")){
                    $new_subtask.History = $subtask.history
                }

                # Link to the parent.            
                if (!$dry_run){
                    $link = new-object Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemLink($linkType.ReverseEnd, $new_task.ID) 
                    $new_subtask.WorkItemLinks.Add($link) >$null
                }

                $invalid_fields = $new_subtask.validate();

                if ($invalid_fields.Count -gt 0){
                    foreach ($field in $invalid_fields){
                        write-host("`t`t`t`t***ERROR*** '{0}': {1}. Field value: '{2}'" -f $field.Name, $field.Status, $field.Value)
                        $errors_count++
                    }

                    if (!$dry_run) {
                        break;
                    }
                }
                    
                if (!$dry_run) {
                    $new_subtask.save()
                    write-host ("`t`t`t- ({0}) '{1}'" -f $new_subtask.Id, (Replace_Placeholders -str $subtask.title -WORK_ITEM_ID $workItemID -PARENT_ITEM_ID $new_task.Id))
                }                   
            }    
        }    
    } 
    write-host   
}

write-host("SUMMARY")
write-host("=======")
write-host("Work Items Processed: {0}" -f $work_items_count)

if (!$dry_run){
    write-host("Tasks Created: {0}" -f $items_created_count)
} else {
    write-host("Tasks to Create: {0}" -f $items_created_count)
}

write-host("Errors: {0}" -f $errors_count)
write-host

if (!$dry_run){
    if ($errors_count -eq 0){
        write-host("Completed, go check TFS!")
    } else {
        write-host("***WARNING*** Errors occured during this run, make sure to review the run log.")
    }
} else {
    if ($errors_count -eq 0){
        write-host("Dry-run completed, review the output and re-run with -dry-run `$false")
    } else {
        write-host("***STOP*** Errors occured during the dry-run. Fix them and do another dry-run before continuing.")
    }
}