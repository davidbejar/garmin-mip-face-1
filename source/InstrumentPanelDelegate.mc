import Toybox.Lang;
import Toybox.WatchUi;

//! Turns off the always-on seconds if onPartialUpdate() exceeds the device's
//! power budget (design/spec.md §8).
class InstrumentPanelDelegate extends WatchUi.WatchFaceDelegate {

    private var _view as InstrumentPanelView;

    function initialize(view as InstrumentPanelView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    function onPowerBudgetExceeded(powerInfo as WatchUi.WatchFacePowerInfo) as Void {
        _view.disablePartialUpdates();
    }
}
