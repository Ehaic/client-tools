# ================================================================================
#
# QuestChecker.ps1 - validation rules for quests
#
# PowerShell port (2026-08-28) of SOE's QuestChecker.pl v1.01 (Copyright 2006,
# Sony Online Entertainment Inc.; original preserved beside this file). Ported
# because the tool machines carry no perl. Rule-for-rule faithful, including
# the original's quirks:
#   * isTrue("") is TRUE (only "false"/"0" are false, empty is not)
#   * numeric comparisons use perl-style numification (leading number, else 0)
#   * the checker always exits 0 after a completed run, even with errors;
#     only bad usage / missing file exits 1
# Output format matches the .pl so anything parsing the console keeps working.
#
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File QuestChecker.ps1 [-h] | [-d] <quest file (.qst)>
#
# ================================================================================

$script:Version = '1.01'
$script:QuestFileName = ''
$script:NumberOfErrors = 0
$script:NumberOfWarnings = 0
$script:Dump = $false

# message types
Set-Variable -Name MSG_WARNING -Value 0 -Option Constant
Set-Variable -Name MSG_ERROR   -Value 1 -Option Constant
# node types
Set-Variable -Name NT_TASK -Value 0 -Option Constant
Set-Variable -Name NT_LIST -Value 1 -Option Constant

# --------------------------------------------------------------------------------

function Show-Usage {
    [Console]::Error.WriteLine("Usage: $($MyInvocation.ScriptName) [-h] | [-d] <quest file (.qst)>")
    [Console]::Error.WriteLine(' Performs rule checks on the quest file and outputs errors and warnings.')
    [Console]::Error.WriteLine(' -d    dumps the data structure that represents the file')
    [Console]::Error.WriteLine(' -h    show usage')
    exit 1
}

# --------------------------------------------------------------------------------

function Get-DataValue([System.Xml.XmlElement]$node, [string]$name) {
    if ($null -eq $node) { return '' }
    foreach ($d in $node.SelectNodes('data')) {
        if ($d.GetAttribute('name') -eq $name) { return [string]$d.GetAttribute('value') }
    }
    return ''
}

# perl numification: leading numeric portion of the string, else 0
function Get-Numeric([System.Xml.XmlElement]$node, [string]$name) {
    $v = Get-DataValue $node $name
    $m = [regex]::Match($v, '^\s*[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?')
    if ($m.Success) { return [double]$m.Value }
    return 0.0
}

function Test-IsTrue([System.Xml.XmlElement]$node, [string]$name) {
    $v = Get-DataValue $node $name
    return -not ($v.ToLower() -eq 'false' -or $v -eq '0')
}

function Test-IsFalse([System.Xml.XmlElement]$node, [string]$name) {
    return -not (Test-IsTrue $node $name)
}

function Test-IsEmpty([System.Xml.XmlElement]$node, [string]$name) {
    return (Get-DataValue $node $name) -eq ''
}

# --------------------------------------------------------------------------------

function Show-Summary {
    Write-Host "`nSummary:`n"
    Write-Host "Errors - $script:NumberOfErrors"
    Write-Host "Warnings - $script:NumberOfWarnings"
    if ($script:NumberOfWarnings -eq 0 -and $script:NumberOfErrors -eq 0) {
        Write-Host "`n!SUCCESS! Quest has NO warnings or errors"
    } else {
        Write-Host "`n!FAILURE! Quest has warnings or errors"
    }
}

# --------------------------------------------------------------------------------

function Write-Message([System.Xml.XmlElement]$node, [int]$nodeType, [string]$field, [int]$messageType, [string]$message) {
    $line = $script:QuestFileName + ' ('
    if ($nodeType -eq $NT_TASK) {
        $line += 'TASK:' + $node.GetAttribute('id') + ':' + $node.GetAttribute('type') + ':'
    } elseif ($nodeType -eq $NT_LIST) {
        $line += 'LIST:'
    } else {
        $line += 'UNKNOWN:'
    }
    $line += $field + ') : '
    if ($messageType -eq $MSG_WARNING) {
        $line += 'WARNING'
        $script:NumberOfWarnings++
    } elseif ($messageType -eq $MSG_ERROR) {
        $line += 'ERROR'
        $script:NumberOfErrors++
    } else {
        $line += 'UNKNOWN'
    }
    Write-Host ($line + ' : ' + $message)
}

# --------------------------------------------------------------------------------

function Test-WaitForTaskEntry([System.Xml.XmlElement]$task, [string]$fileName, [string]$taskName, [string]$displayString) {
    if ((Test-IsEmpty $task $fileName) -and (Test-IsEmpty $task $taskName) -and (Test-IsEmpty $task $displayString)) {
        return $false
    }
    if (Test-IsEmpty $task $fileName) {
        Write-Message $task $NT_TASK $fileName $MSG_ERROR 'Quest filename is required'
    }
    if (Test-IsEmpty $task $taskName) {
        Write-Message $task $NT_TASK $taskName $MSG_ERROR 'Quest task name is required'
    }
    if (Test-IsEmpty $task $displayString) {
        Write-Message $task $NT_TASK $displayString $MSG_WARNING 'Display string is empty so the task counter will not update in the journal or in the helper'
    }
    return $true
}

# --------------------------------------------------------------------------------

function Test-Task([System.Xml.XmlElement]$task) {

    # check base task fields

    if ((Test-IsTrue $task 'isVisible') -and (Test-IsEmpty $task 'journalEntryTitle')) {
        Write-Message $task $NT_TASK 'journalEntryTitle' $MSG_ERROR 'Visible journal has missing title'
    }
    if ((Test-IsTrue $task 'isVisible') -and (Test-IsEmpty $task 'journalEntryDescription')) {
        Write-Message $task $NT_TASK 'journalEntryDescription' $MSG_ERROR 'Visible journal has missing description'
    }
    if ((Test-IsTrue $task 'createWaypoint') -and (Test-IsEmpty $task 'waypointName')) {
        Write-Message $task $NT_TASK 'waypointName' $MSG_ERROR 'Waypoint missing name'
    }
    if (-not (Test-IsEmpty $task 'interiorWaypointAppearance') -or -not (Test-IsEmpty $task 'buildingCellName')) {
        if (Test-IsEmpty $task 'interiorWaypointAppearance') {
            Write-Message $task $NT_TASK 'interiorWaypointAppearance' $MSG_ERROR 'Interior waypoint appearance required for interior waypoints'
        }
        if (Test-IsEmpty $task 'buildingCellName') {
            Write-Message $task $NT_TASK 'buildingCellName' $MSG_ERROR 'Building cell name required for interior waypoints'
        }
        if ((Get-Numeric $task 'LocationY(m)') -eq 0) {
            Write-Message $task $NT_TASK 'LocationY(m)' $MSG_ERROR 'Interior waypoint has a zero Y value which is not valid'
        }
    }
    if ((Test-IsTrue $task 'createEntranceWaypoint') -and (Test-IsEmpty $task 'entranceWaypointName')) {
        Write-Message $task $NT_TASK 'entranceWaypointName' $MSG_ERROR 'Entrance Waypoint missing name'
    }
    if ((Test-IsTrue $task 'createEntranceWaypoint') -and -not (Test-IsTrue $task 'createWaypoint')) {
        Write-Message $task $NT_TASK 'createEntranceWaypoint' $MSG_ERROR 'Entrance Waypoint on but no non-entrance waypoint defined'
    }

    # check task specific fields

    $type = $task.GetAttribute('type')
    switch ($type) {
        'Comm Player' {
            if (Test-IsEmpty $task 'Comm Message Text') {
                Write-Message $task $NT_TASK 'Comm Message Text' $MSG_ERROR 'Message text is required'
            }
            if (Test-IsEmpty $task 'NPC Appearance Server Template') {
                Write-Message $task $NT_TASK 'NPC Appearance Server Template' $MSG_ERROR 'Server appearance template is required'
            }
        }
        'Craft Item' {
            if (Test-IsEmpty $task 'Server Object Template') {
                Write-Message $task $NT_TASK 'Server Object Template' $MSG_ERROR 'Server object template is required'
            }
        }
        'Destroy Multiple' {
            if (-not (Test-IsEmpty $task 'Target Server Template') -and -not (Test-IsEmpty $task 'Social Group')) {
                Write-Message $task $NT_TASK 'Target Server Template' $MSG_WARNING 'Both server template and social group specified. Server template will be ignored'
            }
            if ((Test-IsEmpty $task 'Target Server Template') -and (Test-IsEmpty $task 'Social Group')) {
                Write-Message $task $NT_TASK 'Target Server Template' $MSG_ERROR 'A server template or social group is required'
            }
            if ((Get-Numeric $task 'RewardCredits') -ne 0) {
                Write-Message $task $NT_TASK 'RewardCredits' $MSG_WARNING 'Reward credits is deprecated. Use the global quest reward instead'
            }
        }
        'Destroy Multiple and Loot' {
            if (-not (Test-IsEmpty $task 'CreatureType') -and -not (Test-IsEmpty $task 'Social Group')) {
                Write-Message $task $NT_TASK 'CreatureType' $MSG_WARNING 'Both server template and social group specified. Server template will be ignored'
            }
            if ((Test-IsEmpty $task 'CreatureType') -and (Test-IsEmpty $task 'Social Group')) {
                Write-Message $task $NT_TASK 'CreatureType' $MSG_ERROR 'A server template or social group is required'
            }
            if ((Get-Numeric $task 'RewardCredits') -ne 0) {
                Write-Message $task $NT_TASK 'RewardCredits' $MSG_WARNING 'Reward credits is deprecated. Use the global quest reward instead'
            }
        }
        'Encounter' {
            if (Test-IsEmpty $task 'Creature Type') {
                Write-Message $task $NT_TASK 'Creature Type' $MSG_ERROR 'Creature type is required'
            }
            if ((Get-Numeric $task 'Max Distance') -lt (Get-Numeric $task 'Min Distance')) {
                Write-Message $task $NT_TASK 'Max Distance' $MSG_ERROR 'Max distance cannot be less than min distance'
            }
        }
        'Escort' {
            if (Test-IsEmpty $task 'Escort Creature Type') {
                Write-Message $task $NT_TASK 'Escort Creature Type' $MSG_ERROR 'Escort creature type is required'
            }
        }
        'Give Item To NPC' {
            if (Test-IsEmpty $task 'itemToGive') {
                Write-Message $task $NT_TASK 'itemToGive' $MSG_ERROR 'Item to give is required'
            }
        }
        'Go to Location' {
            if (Test-IsFalse $task 'createWaypoint') {
                Write-Message $task $NT_TASK 'createWaypoint' $MSG_WARNING 'Waypoint not created'
            }
        }
        'Grant Space Quest' {
            if (Test-IsEmpty $task 'questToGrant') {
                Write-Message $task $NT_TASK 'questToGrant' $MSG_ERROR 'Quest to grant is required'
            }
            if (Test-IsEmpty $task 'questType') {
                Write-Message $task $NT_TASK 'questType' $MSG_ERROR 'Quest type is required'
            }
        }
        'Immediately Complete Quest' { }
        'Immediately Clear Quest' { }
        'Nothing' { }
        'Perform' { }
        'Perform Action On Npc' {
            Write-Message $task $NT_TASK 'none' $MSG_ERROR 'Do not use this task'
        }
        'Remote Encounter' {
            if (Test-IsEmpty $task 'creatureName') {
                Write-Message $task $NT_TASK 'creatureName' $MSG_ERROR 'Creature name is required'
            }
            if (Test-IsEmpty $task 'encounterSceneName') {
                Write-Message $task $NT_TASK 'encounterSceneName' $MSG_ERROR 'Encounter scene name is required'
            }
            if ((Get-Numeric $task 'maxDifficulty') -lt (Get-Numeric $task 'minDifficulty')) {
                Write-Message $task $NT_TASK 'maxDifficulty' $MSG_ERROR 'Max difficulty cannot be less than min difficulty'
            }
        }
        'Retrieve Item' {
            if (Test-IsEmpty $task 'Server Object Template') {
                Write-Message $task $NT_TASK 'Server Object Template' $MSG_ERROR 'Server object template is required'
            }
            if (Test-IsEmpty $task 'ItemName') {
                Write-Message $task $NT_TASK 'ItemName' $MSG_ERROR 'Item name is required'
            }
        }
        'Reward' {
            Write-Message $task $NT_TASK 'none' $MSG_WARNING 'Depricated task. Use the reward fields global to the quest instead'
        }
        'Show Message Box' {
            if (Test-IsEmpty $task 'messageBoxTitle') {
                Write-Message $task $NT_TASK 'messageBoxTitle' $MSG_ERROR 'Message box title is required'
            }
            if (Test-IsEmpty $task 'messageBoxText') {
                Write-Message $task $NT_TASK 'messageBoxText' $MSG_ERROR 'Message box text is required'
            }
        }
        'Static Escort' {
            if (Test-IsEmpty $task 'Escort Creature Type') {
                Write-Message $task $NT_TASK 'Escort Creature Type' $MSG_ERROR 'Creature type is required'
            }
        }
        'Talk to Npc' {
            Write-Message $task $NT_TASK 'none' $MSG_WARNING "Depricated task. Use 'Wait for Signal' instead"
        }
        'Timer' {
            if ((Get-Numeric $task 'Max Time') -lt (Get-Numeric $task 'Min Time')) {
                Write-Message $task $NT_TASK 'Max Time' $MSG_ERROR 'Max time cannot be less than min time'
            }
        }
        'Wait for Signal' {
            if (Test-IsEmpty $task 'Signal Name') {
                Write-Message $task $NT_TASK 'Signal Name' $MSG_ERROR 'Signal name is required'
            }
        }
        'Wait for Tasks' {
            $firstMissing = $false
            $skippedTask = $false

            $currentDefined = Test-WaitForTaskEntry $task 'Task1 Quest Filename' 'Task1 taskName' 'Task1 Display String'
            $firstMissing = -not $currentDefined
            $previousDefined = $currentDefined

            foreach ($n in 2..6) {
                $currentDefined = Test-WaitForTaskEntry $task "Task$n Quest Filename" "Task$n taskName" "Task$n Display String"
                if (-not $previousDefined -and $currentDefined) { $skippedTask = $true }
                $previousDefined = $currentDefined
            }

            if ($firstMissing) {
                Write-Message $task $NT_TASK 'none' $MSG_ERROR 'The first task is required'
            }
            if ($skippedTask) {
                Write-Message $task $NT_TASK 'none' $MSG_ERROR 'A task was skipped. Tasks must be defined consecutively'
            }
        }
    }
}

# --------------------------------------------------------------------------------

function Test-Tasks([System.Xml.XmlElement]$node) {
    if ($null -eq $node) { return }
    foreach ($task in $node.SelectNodes('task')) {
        Test-Task $task
        Test-Tasks $task
    }
}

# --------------------------------------------------------------------------------

function Test-List([System.Xml.XmlElement]$list) {
    if (Test-IsEmpty $list 'category') {
        Write-Message $list $NT_LIST 'category' $MSG_ERROR 'Quest journal category is required'
    }
    if (Test-IsEmpty $list 'journalEntryTitle') {
        Write-Message $list $NT_LIST 'journalEntryTitle' $MSG_ERROR 'Quest journal title is required'
    }
    if (Test-IsEmpty $list 'journalEntryDescription') {
        Write-Message $list $NT_LIST 'journalEntryDescription' $MSG_ERROR 'Quest journal description is required'
    }
}

# --------------------------------------------------------------------------------

function Show-Dump([System.Xml.XmlElement]$node, [int]$indent = 0) {
    # approximation of Data::Dumper for the -d flag
    $pad = ' ' * $indent
    $attrs = ($node.Attributes | ForEach-Object { "$($_.Name)='$($_.Value)'" }) -join ' '
    Write-Host "$pad<$($node.LocalName) $attrs>"
    foreach ($child in $node.ChildNodes) {
        if ($child -is [System.Xml.XmlElement]) { Show-Dump $child ($indent + 2) }
    }
}

# --------------------------------------------------------------------------------

function Invoke-Main {
    [xml]$doc = Get-Content -LiteralPath $script:QuestFileName -Raw

    if ($script:Dump) {
        Show-Dump $doc.DocumentElement
    } else {
        Write-Host "Checking quest '$script:QuestFileName'`n"
        Write-Host '*** checking tasks ***'
        Test-Tasks $doc.DocumentElement.SelectSingleNode('tasks')
        Write-Host '*** checking list ***'
        Test-List $doc.DocumentElement.SelectSingleNode('list')
        Show-Summary
    }
}

# ================================================================================

Write-Host "`n# Quest Checker Version $script:Version`n"

if ($args.Count -lt 1) { Show-Usage }

$argList = @($args)
while ($argList.Count -gt 1) {
    if ($argList[0] -eq '-d') { $script:Dump = $true }
    elseif ($argList[0] -eq '-h') { Show-Usage }
    else { Show-Usage }
    $argList = $argList[1..($argList.Count - 1)]
}
if ($argList[0] -eq '-h') { Show-Usage }

$script:QuestFileName = [string]$argList[0]

if (-not (Test-Path -LiteralPath $script:QuestFileName)) {
    Write-Host "File does not exist: '$script:QuestFileName'"
    Show-Usage
}

Invoke-Main
exit 0

# ================================================================================
