// ======================================================================
//
// ScriptShellView.cpp
// asommers 2003-09-23
//
// copyright2003, sony online entertainment
// 
// ======================================================================

#include "FirstSwgConversationEditor.h"
#include "ScriptShellView.h"

#include "sharedFoundation/ConfigFile.h"
#include "sharedUtility/FileName.h"
#include "SwgConversationEditorDoc.h"

// ======================================================================

IMPLEMENT_DYNCREATE(ScriptShellView, CShellView)

// ======================================================================

ScriptShellView::ScriptShellView()
{
}

// ----------------------------------------------------------------------

ScriptShellView::~ScriptShellView()
{
}

// ======================================================================

BEGIN_MESSAGE_MAP(ScriptShellView, CShellView)
	//{{AFX_MSG_MAP(ScriptShellView)
		// NOTE - the ClassWizard will add and remove mapping macros here.
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

// ======================================================================

#ifdef _DEBUG
void ScriptShellView::AssertValid() const
{
	CShellView::AssertValid();
}

void ScriptShellView::Dump(CDumpContext& dc) const
{
	CShellView::Dump(dc);
}
#endif //_DEBUG

// ----------------------------------------------------------------------

void ScriptShellView::OnUpdate(CView * const pSender, LPARAM const lHint, CObject * const pHint) 
{
	if (pSender != this)
	{
		switch (lHint)
		{
		case SwgConversationEditorDoc::H_shellCompile:
			{
				char const * const mochaCommand = ConfigFile::getKeyString ("SwgConversationEditor", "mochaCommand", 0);
				if (mochaCommand)
				{
					SwgConversationEditorDoc::ShellData * const shellData = safe_cast<SwgConversationEditorDoc::ShellData *> (pHint);
					if (shellData)
					{
						CString const releaseOption = shellData->m_debug ? " " : " --buildRelease ";
						CString const commandLine = mochaCommand + releaseOption + shellData->m_fullScriptFileName;

						CString buffer;
						buffer.Format ("-------------------- Compilation: %s %s --------------------\r\n", shellData->m_shortFileName.GetString (), shellData->m_debug ? "Debug" : "Release");
						AddTexts (buffer);

						buffer.Format ("Created %s.stf\r\n", shellData->m_shortFileName.GetString ());
						AddTexts (buffer);

						buffer.Format ("Created %s.java\r\n", shellData->m_shortFileName.GetString ());
						AddTexts (buffer);

						buffer.Format ("Compiling %s.java\r\n", shellData->m_shortFileName.GetString ());
						AddTexts (buffer);

						CreateShellRedirect (commandLine);
					}
				}
				else
					MessageBox ("Could not spawn script compiler because 'mochaCommand' has not been defined in SwgConversationEditor.cfg");

				delete pHint;
			}
			break;

		default:
			break;
		}
	}
}

// ======================================================================

