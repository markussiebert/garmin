import Toybox.Application;
import Toybox.WatchUi;

class ChartsApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new $.ChartsView();
        return [view];
    }
}
