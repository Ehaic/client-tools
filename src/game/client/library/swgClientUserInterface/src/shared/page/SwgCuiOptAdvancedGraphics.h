#ifndef INCLUDED_SwgCuiOptAdvancedGraphics_H
#define INCLUDED_SwgCuiOptAdvancedGraphics_H
#include "swgClientUserInterface/SwgCuiOptBase.h"
#include <vector>
class UIComboBox;
class UIText;
class SwgCuiOptAdvancedGraphics : public SwgCuiOptBase
{
public:
    explicit SwgCuiOptAdvancedGraphics(UIPage &page);
    virtual void OnButtonPressed(UIWidget *context);
    virtual void storeRevertData();
    virtual void revert();
    virtual void update(float deltaTimeSecs);
protected:
    virtual void performActivate();
    virtual void performDeactivate();
private:
    struct Display { int width, height; bool borderless, vsync; };
    static Display current();
    void apply(Display const &display);
    void refresh();
    void rollback();
    UIComboBox *m_resolution;
    UIComboBox *m_mode;
    UIComboBox *m_vsync;
    UIButton *m_apply;
    UIButton *m_keep;
    UIButton *m_revert;
    UIText *m_status;
    std::vector<Display> m_modes;
    Display m_original;
    Display m_previous;
    bool m_preview;
    unsigned long m_previewStart;
    SwgCuiOptAdvancedGraphics(SwgCuiOptAdvancedGraphics const &);
    SwgCuiOptAdvancedGraphics &operator=(SwgCuiOptAdvancedGraphics const &);
};
#endif
