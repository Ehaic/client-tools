#include "swgClientUserInterface/FirstSwgClientUserInterface.h"
#include "SwgCuiOptAdvancedGraphics.h"
#include "clientGraphics/Graphics.h"
#include "clientUserInterface/CuiManager.h"
#include "sharedFoundation/Os.h"
#include "UIButton.h"
#include "UIComboBox.h"
#include "UIText.h"
#include "UnicodeUtils.h"
#include <windows.h>
#include <cstdio>

SwgCuiOptAdvancedGraphics::SwgCuiOptAdvancedGraphics(UIPage &page) :
    SwgCuiOptBase("SwgCuiOptAdvancedGraphics", page), m_resolution(0), m_mode(0), m_vsync(0),
    m_apply(0), m_keep(0), m_revert(0), m_status(0), m_preview(false), m_previewStart(0)
{
    getCodeDataObject(TUIComboBox, m_resolution, "resolution");
    getCodeDataObject(TUIComboBox, m_mode, "mode");
    getCodeDataObject(TUIComboBox, m_vsync, "vsync");
    getCodeDataObject(TUIButton, m_apply, "apply");
    getCodeDataObject(TUIButton, m_keep, "keep");
    getCodeDataObject(TUIButton, m_revert, "revert");
    getCodeDataObject(TUIText, m_status, "status");
    registerMediatorObject(*m_apply, true);
    registerMediatorObject(*m_keep, true);
    registerMediatorObject(*m_revert, true);
    m_mode->AddItem(Unicode::narrowToWide("Windowed"), "windowed");
    m_mode->AddItem(Unicode::narrowToWide("Borderless fullscreen"), "borderless");
    m_vsync->AddItem(Unicode::narrowToWide("On"), "on");
    m_vsync->AddItem(Unicode::narrowToWide("Off"), "off");
    m_original = m_previous = current();
}

SwgCuiOptAdvancedGraphics::Display SwgCuiOptAdvancedGraphics::current()
{
    Display d;
    d.width = Graphics::getFrameBufferMaxWidth();
    d.height = Graphics::getFrameBufferMaxHeight();
    Graphics::getAdvancedDisplayOptions(d.borderless, d.vsync);
    return d;
}
void SwgCuiOptAdvancedGraphics::apply(Display const &d)
{
    Graphics::applyAdvancedDisplayOptions(d.width, d.height, d.borderless, d.vsync);
    CuiManager::setSize(Graphics::getFrameBufferMaxWidth(), Graphics::getFrameBufferMaxHeight());
    // A smaller resolution must not strand the confirmation buttons off-screen.
    for (UIBaseObject *node = &getPage(); node; node = node->GetParent())
    {
        if (node->GetName() != "OptMain" || !node->IsA(TUIWidget)) continue;
        UIWidget *window = static_cast<UIWidget *>(node);
        UIBaseObject *parent = window->GetParent();
        if (!parent || !parent->IsA(TUIWidget)) break;
        UISize const available = static_cast<UIWidget *>(parent)->GetSize();
        UISize const size = window->GetSize();
        UIPoint position = window->GetLocation();
        if (position.x + size.x > available.x) position.x = available.x - size.x;
        if (position.y + size.y > available.y) position.y = available.y - size.y;
        if (position.x < 0) position.x = 0;
        if (position.y < 0) position.y = 0;
        window->SetLocation(position);
        break;
    }
}
void SwgCuiOptAdvancedGraphics::storeRevertData()
{
    m_original = current();
}
void SwgCuiOptAdvancedGraphics::revert()
{
    rollback();
    apply(m_original);
    Graphics::rememberAdvancedDisplayOptions();
    refresh();
}
void SwgCuiOptAdvancedGraphics::refresh()
{
    Display const active = current();
    m_modes.clear();
    m_resolution->Clear();
    // Keep the current dimensions available even if Wine does not enumerate them.
    m_modes.push_back(active);
    MONITORINFOEX monitor = {};
    monitor.cbSize = sizeof(monitor);
    bool const haveMonitor = GetMonitorInfo(MonitorFromWindow(Os::getWindow(), MONITOR_DEFAULTTONEAREST), reinterpret_cast<MONITORINFO *>(&monitor)) != FALSE;
    DEVMODE mode = {};
    mode.dmSize = sizeof(mode);
    for (DWORD i = 0; EnumDisplaySettings(haveMonitor ? monitor.szDevice : NULL, i, &mode); ++i)
    {
        if (mode.dmPelsWidth < 800 || mode.dmPelsHeight < 600 || mode.dmPelsWidth > 16384 || mode.dmPelsHeight > 16384) continue;
        bool found = false;
        for (size_t j = 0; j < m_modes.size(); ++j)
            if (m_modes[j].width == static_cast<int>(mode.dmPelsWidth) && m_modes[j].height == static_cast<int>(mode.dmPelsHeight)) found = true;
        if (!found)
        {
            Display d = active;
            d.width = static_cast<int>(mode.dmPelsWidth);
            d.height = static_cast<int>(mode.dmPelsHeight);
            m_modes.push_back(d);
        }
    }
    for (size_t i = 0; i < m_modes.size(); ++i)
    {
        char text[64];
        _snprintf_s(text, sizeof(text), _TRUNCATE, "%d x %d", m_modes[i].width, m_modes[i].height);
        m_resolution->AddItem(Unicode::narrowToWide(text), text);
    }
    m_resolution->SetSelectedIndex(0);
    m_mode->SetSelectedIndex(active.borderless ? 1 : 0);
    m_vsync->SetSelectedIndex(active.vsync ? 0 : 1);
    bool const supported = Graphics::supportsAdvancedDisplayOptions();
    m_apply->SetEnabled(supported && !m_preview);
    m_resolution->SetEnabled(supported && !m_preview);
    m_mode->SetEnabled(supported && !m_preview);
    m_vsync->SetEnabled(supported && !m_preview);
    m_keep->SetVisible(m_preview);
    m_revert->SetVisible(m_preview);
    if (!m_preview)
        m_status->SetLocalText(Unicode::narrowToWide(supported ?
            "Choose settings, then Apply. Choose Keep settings or the options OK button within 15 seconds. OK also saves." :
            "These controls require the updated DX11 renderer."));
}
void SwgCuiOptAdvancedGraphics::performActivate()
{
    SwgCuiOptBase::performActivate();
    refresh();
    setIsUpdating(true);
}
void SwgCuiOptAdvancedGraphics::performDeactivate()
{
    rollback();
    setIsUpdating(false);
    SwgCuiOptBase::performDeactivate();
}
void SwgCuiOptAdvancedGraphics::rollback()
{
    if (!m_preview) return;
    m_preview = false;
    apply(m_previous);
    refresh();
    m_status->SetLocalText(Unicode::narrowToWide("Previous display settings restored."));
}
void SwgCuiOptAdvancedGraphics::confirmPreview()
{
    if (!m_preview) return;
    // OK and Keep must observe the same deadline, even between update ticks.
    if (GetTickCount() - m_previewStart >= 15000) { rollback(); return; }
    m_preview = false;
    Graphics::rememberAdvancedDisplayOptions();
    refresh();
    m_status->SetLocalText(Unicode::narrowToWide("Settings kept. Choose OK to save, or Cancel to restore the settings from when you opened options."));
}
void SwgCuiOptAdvancedGraphics::OnButtonPressed(UIWidget *context)
{
    if (context == m_apply && !m_preview && Graphics::supportsAdvancedDisplayOptions())
    {
        long const index = m_resolution->GetSelectedIndex();
        if (index < 0 || static_cast<size_t>(index) >= m_modes.size()) return;
        Display next = m_modes[index];
        next.borderless = m_mode->GetSelectedIndex() == 1;
        next.vsync = m_vsync->GetSelectedIndex() == 0;
        if (next.borderless)
        {
            MONITORINFO monitor = {};
            monitor.cbSize = sizeof(monitor);
            if (!GetMonitorInfo(MonitorFromWindow(Os::getWindow(), MONITOR_DEFAULTTONEAREST), &monitor)) return;
            next.width = monitor.rcMonitor.right - monitor.rcMonitor.left;
            next.height = monitor.rcMonitor.bottom - monitor.rcMonitor.top;
        }
        m_previous = current();
        m_preview = true;
        m_previewStart = GetTickCount();
        apply(next);
        refresh();
        update(0.f);
    }
    else if (context == m_keep && m_preview)
    {
        confirmPreview();
    }
    else if (context == m_revert)
        rollback();
    else
        SwgCuiOptBase::OnButtonPressed(context);
}
void SwgCuiOptAdvancedGraphics::update(float deltaTimeSecs)
{
    SwgCuiOptBase::update(deltaTimeSecs);
    if (!m_preview) return;
    DWORD const elapsed = GetTickCount() - m_previewStart;
    if (elapsed >= 15000) { rollback(); return; }
    char text[160];
    _snprintf_s(text, sizeof(text), _TRUNCATE, "Choose Keep settings or OK. Reverting in %lu seconds. Leaving this page reverts the preview.", (15000 - elapsed + 999) / 1000);
    m_status->SetLocalText(Unicode::narrowToWide(text));
}
