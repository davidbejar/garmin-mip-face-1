import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! On-watch settings (design/spec.md §9), shown from the system Watch Face menu
//! via AppBase.getSettingsView(). One item per setting; each opens its option list with
//! the current choice marked. Objects exist only while the menu is open.
class SettingsMenu extends WatchUi.Menu2 {

    //! Per setting: property key, title, option names.
    static const KEYS = [Settings.TEXT_COLOUR, Settings.ACCENT_COLOUR, Settings.HEART_RATE_LABEL,
        Settings.TIME_FONT, Settings.RUBBER_DUCK] as Array<String>;

    function initialize() {
        Menu2.initialize({:title => Rez.Strings.SettingsTitle});
        for (var i = 0; i < KEYS.size(); i++) {
            var names = SettingsMenu.optionNames(i);
            var current = Settings.index(KEYS[i], names.size());
            addItem(new WatchUi.MenuItem(SettingsMenu.title(i), names[current], i, null));
        }
    }

    static function title(setting as Number) as ResourceId {
        var titles = [Rez.Strings.TextColourTitle, Rez.Strings.AccentTitle, Rez.Strings.HeartRateLabelTitle,
            Rez.Strings.TimeFontTitle, Rez.Strings.RubberDuckTitle] as Array<ResourceId>;
        return titles[setting];
    }

    static function optionNames(setting as Number) as Array<ResourceId> {
        if (setting == 0) {
            return [Rez.Strings.TextBlack, Rez.Strings.TextNavy, Rez.Strings.TextPurple] as Array<ResourceId>;
        }
        if (setting == 1) {
            return [Rez.Strings.AccentOrange, Rez.Strings.AccentMagenta, Rez.Strings.AccentAmber] as Array<ResourceId>;
        }
        if (setting == 2) {
            return [Rez.Strings.HeartRateRest, Rez.Strings.HeartRateMax] as Array<ResourceId>;
        }
        if (setting == 3) {
            return [Rez.Strings.TimeFontClassic, Rez.Strings.TimeFontBold, Rez.Strings.TimeFontLcd,
                Rez.Strings.TimeFontDots, Rez.Strings.TimeFontHand] as Array<ResourceId>;
        }
        return [Rez.Strings.Off, Rez.Strings.On] as Array<ResourceId>;
    }
}

//! Top level: opens the option list for the chosen setting.
class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var setting = item.getId() as Number;
        var names = SettingsMenu.optionNames(setting);
        var key = SettingsMenu.KEYS[setting];
        var current = Settings.index(key, names.size());

        var options = new WatchUi.Menu2({:title => SettingsMenu.title(setting)});
        for (var i = 0; i < names.size(); i++) {
            options.addItem(new WatchUi.MenuItem(names[i], (i == current) ? "✓" : null, i, null));
        }
        options.setFocus(current);
        WatchUi.pushView(options, new SettingsOptionDelegate(key, item, names), WatchUi.SLIDE_LEFT);
    }
}

//! Option list: stores the choice, updates the parent item and the face.
class SettingsOptionDelegate extends WatchUi.Menu2InputDelegate {

    private var _key as String;
    private var _parent as WatchUi.MenuItem;
    private var _names as Array<ResourceId>;

    function initialize(key as String, parent as WatchUi.MenuItem, names as Array<ResourceId>) {
        Menu2InputDelegate.initialize();
        _key = key;
        _parent = parent;
        _names = names;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var choice = item.getId() as Number;
        Settings.setIndex(_key, choice);
        _parent.setSubLabel(_names[choice]);
        (Application.getApp() as InstrumentPanelApp).onSettingsChanged();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
