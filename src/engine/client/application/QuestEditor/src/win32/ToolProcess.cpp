// ======================================================================
//
// ToolProcess.cpp
// Copyright 2004, Sony Online Entertainment Inc.
//
// ======================================================================

#include "FirstQuestEditor.h"

// ----------------------------------------------------------------------

#include "ToolProcess.h"

// ----------------------------------------------------------------------

#include "ToolProcess.moc"

// ----------------------------------------------------------------------

ToolProcess::ToolProcess(char const * const toolDirectory)
: QProcess()
, m_procArgList()
{
	IGNORE_RETURN(connect(this, SIGNAL(readyReadStdout()), this, SLOT(slotReadProcessOutput())));
	IGNORE_RETURN(connect(this, SIGNAL(readyReadStderr()), this, SLOT(slotReadProcessOutput())));
	IGNORE_RETURN(connect(this, SIGNAL(processExited()), this, SLOT(slotProcessExited())));

	QProcess::setWorkingDirectory(QDir(toolDirectory));
}

// ----------------------------------------------------------------------

ToolProcess::~ToolProcess()
{
}

// ----------------------------------------------------------------------

void ToolProcess::startNextProcess()
{
	QString cmdString;

	if (isRunning())
		return;

	if (m_procArgList.empty())
	{
		consoleOutput("\n*********** DONE ***********\n\n");
		QApplication::beep();
		return;
	}

	StringVector v = m_procArgList.front();
	m_procArgList.pop_front();

	clearArguments();
	for (StringVector::iterator i = v.begin(); i != v.end(); ++i)
	{
		addArgument(i->c_str());

		if(!cmdString.isEmpty())
			IGNORE_RETURN(cmdString.append(" "));

		IGNORE_RETURN(cmdString.append(i->c_str()));
	}

	if (!start())
	{
		emit consoleOutput("*** Failure: [" + cmdString + "] ***\n");

		//-- if there is a failure, run the next process
		emit processExited();
	}
	else
		emit consoleOutput(cmdString + "\n");
}

// ----------------------------------------------------------------------

void ToolProcess::slotReadProcessOutput()
{
	emit consoleOutput(readStdout());
	emit consoleOutput(readStderr());
}

// ----------------------------------------------------------------------

void ToolProcess::slotProcessExited()
{
	startNextProcess();
}

// ----------------------------------------------------------------------

void ToolProcess::compileDataTable(char const * const filename)
{
	StringVector v;

	v.push_back("DataTableTool");
	v.push_back("-i");
	v.push_back(filename);

	m_procArgList.push_back(v);

	startNextProcess();
}

// ----------------------------------------------------------------------

void ToolProcess::checkQuest(char const * const filename)
{
	StringVector v;

	// QuestChecker was a perl script (../exe/win32/QuestChecker.pl); the tool
	// machines carry no perl, so it was ported to PowerShell (2026-08-28).
	// The port lives in the tracked preservation store, reached relative to
	// the Release working directory like the other ../../exe/win32 payloads.
	v.push_back("powershell");
	v.push_back("-NoProfile");
	v.push_back("-ExecutionPolicy");
	v.push_back("Bypass");
	v.push_back("-File");
	v.push_back("../../exe/win32/QuestChecker.ps1");
	v.push_back(filename);

	m_procArgList.push_back(v);

	startNextProcess();
}

// ----------------------------------------------------------------------

void ToolProcess::buildQuestCrcStringTables(char const * const branch)
{
	StringVector v;

	// buildQuestCrcStringTables was a perl Perforce wrapper around
	// buildCrcStringTable.pl; the tool machines carry no perl or p4, so both
	// were ported into one PowerShell script (2026-08-29) that walks the
	// questlist directory instead of asking p4. Same tracked store and spawn
	// shape as QuestChecker above.
	v.push_back("powershell");
	v.push_back("-NoProfile");
	v.push_back("-ExecutionPolicy");
	v.push_back("Bypass");
	v.push_back("-File");
	v.push_back("../../exe/win32/BuildQuestCrcStringTables.ps1");
	v.push_back("-Branch");
	v.push_back(branch);

	m_procArgList.push_back(v);

	startNextProcess();
}

// ======================================================================
