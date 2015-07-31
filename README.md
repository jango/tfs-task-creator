# tfs-task-creator
tfs-task-creater is a Power Shell script for TFS that creates a set of predefined tasks for a set of specified work items. Tasks can have subtasks and each task or subtask can have a title and optional assignee and history comment. 

# Prerequisites
- [TFS Power Tools](https://visualstudiogallery.msdn.microsoftt.com/f017b10c-02b4-4d6d-9845-58a06545627f) with __PowerShell Cmdlets__ feature installed (you need to use Custom Setup during installation to be able to choose that). 
- In order to execute local unsigned PowerShell scripts you may need to change your execution policy by running `set-executionpolicy remotesigned` in a PowerShell window.

# Configuration
An XML file is used to configure the script, a sample is shown below.

```xml
<?xml version="1.0"?>
<settings>
    <!-- TFS Collection URL -->
    <tfs_server>https://server.com/tfs</tfs_server>
    
    <!-- Exact TFS Project name -->
    <tfs_project>Project</tfs_project>
    <tasks>
        <!-- A single task, {{PARENT_ITEM_ID}} will be substituted with the ID of the
        work item for which the task is being created. -->
        <task assignee="Smith, John" history="Parent task comment" title="Parent task 1 for item {{WORK_ITEM_ID}}"/>
        <!-- A task that has subtasks. --> 
        <task assignee="Smith, John" title="Parent task 2 for item {{WORK_ITEM_ID}}" history="Start by providing an estimate for this item.">
            <tasks>
                <!-- {{PARENT_ITEM_ID}} will be substituted with the ID of the
                immediate parent of this task. -->
                <task assignee="" title="Subtask task for item {{PARENT_ITEM_ID}}" />
            </tasks>
        </task>
    </tasks>

    <!-- Each parent item tag contains a signle TFS ID of a work item for
         which the above task list will be generated OR a single Iteration
         Path in which tasks will be generated for all User Stories. -->
    <parent_items>
        <parent_item ID="142344"/>
        <parent_item Iteration="Test iteration"/>
    </parent_items>
</settings>
```

# Running the script
Once you have created a configuration file, you can supply it to the script with `-config` argument. By default, the script runs in "dry-run" mode, meaning that  the script by Dry run allows you to priview which items will be created. Script runs in the dry-run mode by default. Here is an example of a dry-run:

```
.\TFSTaskCreator -config config.xml
```

Output:
```
******DRY RUN, NO CHANGES WILL BE SAVED. RUN WITH -dry_run $false TO COMMIT CHANGES******
Connecting to:
TFS Server: https://server/path
TFS Project: Project

Work Item 188109:
	Work Item Title: Test User Story
	Area Path:       AreaPath
	Iteration Path:  IterationPath
	Tasks: 
		- 'Parent task 1 for item 188109'
			- 'Subtask task for item <ID>'
		- 'Parent task 2 for item 188109'

Work Item 208095:
	Work Item Title: test
	Area Path:       AreaPath
	Iteration Path:  Test iteration
	Tasks: 
		- 'Parent task 1 for item 208095'
			- 'Subtask task for item <ID>'
		- 'Parent task 2 for item 208095'

SUMMARY
=======
Work Items Processed: 2
Tasks to Create: 6
Errors: 0

Dry-run completed, review the output and re-run with -dry-run $false
```

If you are happy with the result, you can run the actual script by adding an extra flag:

```
.\TFSTaskCreator -config "config.xml" -dru-run $false
```
Output:
```
Connecting to:
TFS Server: https://server/path
TFS Project: Project

Create tasks? Y/y to continue, any other key to cancel: y

Work Item 188109:
	Work Item Title: Test User Story
	Area Path:       AreaPath
	Iteration Path:  Test iteration
	Tasks: 
		- (227276) 'Parent task 1 for item 188109'
			- (227277) 'Subtask task for item 227276'
		- (227278) 'Parent task 2 for item 188109'

Work Item 208095:
	Work Item Title: test
	Area Path:       AreaPath
	Iteration Path:  Test iteration
	Tasks: 
		- (227279) 'Parent task 1 for item 208095'
			- (227280) 'Subtask task for item 227279'
		- (227281) 'Parent task 2 for item 208095'

SUMMARY
=======
Work Items Processed: 2
Tasks Created: 6
Errors: 0

Completed, go check TFS!
```

# License
MIT

# Credits
A big inspiration for this script was this [blog post](https://programmaticponderings.wordpress.com/2012/04/15/automating-task-creation-in-team-foundation-server-with-powershell/) by Gary A. Stafford.