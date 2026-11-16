import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class InstrumentPanelApp extends Application.AppBase {

    private var _view as InstrumentPanelView? = null;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new InstrumentPanelView();
        _view = view;
        return [view, new InstrumentPanelDelegate(view)];
    }

    //! On-watch settings, from the system Watch Face menu (spec §9).
    function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
        return [new SettingsMenu(), new SettingsMenuDelegate()];
    }

    //! Settings changed in Garmin Connect, the simulator editor, or the on-watch menu.
    function onSettingsChanged() as Void {
        var view = _view;
        if (view != null) {
            view.reloadSettings();
        }
        WatchUi.requestUpdate();
    }
}
