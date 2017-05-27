################################################################################
#
# Beagle Pup Nasal Functions, Listeners and Commands
#
# Copyright (c) 2015-2017 Richard Senior
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.
#
################################################################################

var Magnetos = {OFF: 0, LEFT: 1, RIGHT: 2, BOTH: 3};
var Tank = {OFF: 0, LEFT: 1, BOTH: 2, RIGHT: 3};
var LandTaxi = {TAXI: 0, OFF: 1, LAND:2};

################################################################################
# Helpers
################################################################################

var _lock = 0;

# Lock changes through listeners. If a function is wrapped in this lock
# function, listeners will not fire and cause an endless loop.
#
var lock = func(f)
{
    if (_lock) return;
    _lock = 1;
    call(f);
    _lock = 0;
}

# Location

var current_position = func()
{
    var lat = getprop("position/latitude-deg");
    var lon = getprop("position/longitude-deg");
    return geo.Coord.new().set_latlon(lat, lon);
}

var distance_to_nearest_runway = func(from)
{
    var airport = airportinfo();
    var distance = 99999;
    foreach (var runway; values(airport.runways)) {
        var r = geo.Coord.new().set_latlon(runway.lat, runway.lon);
        var d = from.distance_to(r);
        if (d < distance) distance = d;
    }
    return distance;
}

var is_near_runway = func()
{
    return distance_to_nearest_runway(from:current_position()) < 50.0;
}

# Multi-position switches

# Step a multi-position switch through intermediate values
#
var step = func(property, value, delay, min, max)
{
    var current = getprop(property);
    if (current == value)
        return;
    if (value < min or value > max) {
        printlog("warn", "Invalid value "~value~" for property "~property);
        return;
    }
    var sense = value > current ? 1 : -1;
    setprop(property, current + sense);
    click();
    var t = maketimer(delay, func {
        step(property, value, delay, min, max);
    });
    t.singleShot = 1;
    t.start();
}

var select_fuel_tank = func(n)
{
    step("controls/fuel/tank-selector", n, 0.3, 0, 3);
}

var select_magnetos = func(n)
{
    step("controls/engines/engine/magnetos", n, 0.2, 0, 3);
}

var select_landtaxi = func(n)
{
    step("controls/switches/land-taxi", n, 0.2, 0, 2);
}

# Switches

var click = func
{
    setprop("sim/sound/click", 1);
    var t = maketimer(0.1, func {
        setprop("sim/sound/click", 0);
    });
    t.singleShot = 1;
    t.start();
}

var switch = func(command, node)
{
    var property = node.getNode("property").getValue();
    var oldValue = getprop(property);
    fgcommand(command, node);
    if (oldValue != getprop(property))
        click();
}

################################################################################
# Controls Overrides
################################################################################

var defaultStartEngine = controls.startEngine;

controls.startEngine = func(v = 1, which...)
{
    if (!v or getprop("systems/electrical/outputs/starter") > 0.0)
        defaultStartEngine(v, size(which) ? which : 0);
}

var defaultFlapsDown = controls.flapsDown;

controls.flapsDown = func(step)
{
    if (getprop("systems/electrical/outputs/flaps") > 0.0)
        defaultFlapsDown(step);
}

controls.stepMagnetos = func(change)
{
    var m = getprop("controls/engines/engine/magnetos");
    select_magnetos(m + change);
}

################################################################################
# Electrical
################################################################################

var beacon = maketimer(1, func {
    setprop("controls/lighting/beacon-state", 1);
    var flash = maketimer(0.2, func {
        setprop("controls/lighting/beacon-state", 0);
    });
    flash.singleShot = 1;
    flash.start();
});

setlistener("systems/electrical/outputs/beacon", func (volts) {
    if (volts.getValue() == 0) {
        beacon.stop();
    } else if (!beacon.isRunning) {
        beacon.start();
        setprop("sim/checklists/status/beacon", 1);
    }
}, 0, 0);

setlistener("systems/electrical/outputs/bus-dc", func (volts) {
    if (volts.getValue() > 0) {
        setprop("sim/checklists/status/battery", 1);
    }
}, 0, 0);

setlistener("systems/electrical/outputs/nav-lights", func (volts) {
    if (volts.getValue() > 0) {
        setprop("sim/checklists/status/nav-lights", 1);
    }
}, 0, 0);

# If the battery is turned off while the alternator is charging, the alt-field
# circuit breaker trips to protect the output diodes of the alternator.
#
setlistener("controls/electric/battery-switch", func(node) {
    if (!node.getBoolValue()) {
        if (getprop("systems/electrical/outputs/alternator-field"))
            setprop("controls/switches/circuit-breakers/alt-field", 0);
    }
});

################################################################################
# Fuel
################################################################################

# Update the fuel and payload dialog from the fuel selection
#
setlistener("controls/fuel/tank-selector", func(node) {
    lock(func {
        var selection = node != nil and node.getValue();
        var l = selection == Tank.LEFT or selection == Tank.BOTH;
        var r = selection == Tank.RIGHT or selection == Tank.BOTH;
        setprop("consumables/fuel/tank[1]/selected", l);
        setprop("consumables/fuel/tank[2]/selected", r);
    });
}, startup = 1, runtime = 0);

# Infer the position of the fuel tank selector from the fuel and
# payload dialog checkboxes.
#
var infer_fuel_tank_selector = func
{
    var l = getprop("consumables/fuel/tank[1]/selected");
    var r = getprop("consumables/fuel/tank[2]/selected");

    if (!l and !r)
        select_fuel_tank(Tank.OFF);
    elsif (l and !r)
        select_fuel_tank(Tank.LEFT);
    elsif (!l and r)
        select_fuel_tank(Tank.RIGHT);
    else
        select_fuel_tank(Tank.BOTH);
}

setlistener("consumables/fuel/tank[1]/selected", func(node) {
    lock(func {
        infer_fuel_tank_selector();
    });
}, startup = 1, runtime = 0);

setlistener("consumables/fuel/tank[2]/selected", func(node) {
    lock(func {
        infer_fuel_tank_selector();
    });
}, startup = 1, runtime = 0);

################################################################################
# Liveries
################################################################################

aircraft.livery.init("Models/Liveries/"~getprop("sim/aero"));

################################################################################
# Commands
################################################################################

# Checklists

addcommand("autostart", func {
    if (props.globals.getNode("sim/checklists/auto") == nil) {
        var message = "Automated checklists need FGDATA 3.5 or higher";
        setprop("sim/messages/copilot", message);
        return;
    }
    if (!getprop("gear/gear/wow")) {
        var message = "Autostart in the air is not yet supported";
        setprop("sim/messages/copilot", message);
        return;
    }
    if (is_near_runway()) {
        setprop("sim/checklists/auto/completed-message",
            "Checklists complete, ready for takeoff"
        );
        generic.complete_checklists("runway-start");
    } else {
        setprop("sim/checklists/auto/completed-message",
            "Checklists complete, ready to taxi"
        );
        generic.complete_checklists("apron-start");
    }
});

addcommand("complete-checklists", func(node) {
    if (props.globals.getNode("sim/checklists/auto") == nil) {
        var message = "Automated checklists need FGDATA 3.5 or higher";
        setprop("sim/messages/copilot", message);
        printlog("warn", message);
        return;
    }
    var checklist = node.getNode("name");
    if (checklist == nil) {
        printlog("warn", "Missing checklist name in "~node.getPath());
        return;
    }
    var waitNode = node.getNode("wait");
    var wait = waitNode != nil ? waitNode.getValue() : 1;
    generic.complete_checklists(checklist.getValue(), wait);
});

addcommand("align-heading-indicator", func {
    var h = getprop("orientation/heading-deg");
    var m = getprop("orientation/heading-magnetic-deg");
    var o = getprop("instrumentation/heading-indicator/offset-deg");
    var d = (o > 180) ? int(m - h) + 360 : int(m - h);
    interpolate("instrumentation/heading-indicator/offset-deg", d, 1.0);
});

addcommand("set-altimeter-qnh", func {
    var rwx = getprop("environment/realwx/enabled");
    var qnh = getprop("environment/metar/pressure-inhg");
    # This is probably a bug in weather scenarios. If the altimeter
    # setting is taken from the METAR string in the scenario, the altitude
    # is wrong, but if it is set from sea level pressure, it comes out
    # correct. At some point this will be fixed in FG and this fudge will
    # need removing.
    var slp = getprop("environment/pressure-sea-level-inhg");
    var setting = rwx ? qnh : slp;
    setting = math.round(setting * 100) / 100;
    interpolate("instrumentation/altimeter/setting-inhg", setting, 1.0);
});

addcommand("start-engine", func(node) {
    if (getprop("engines/engine/cranking") or getprop("engines/engine/running"))
        return;
    controls.startEngine(1);
    var timeNode = node.getNode("time");
    var time = timeNode == nil ? 3 : timeNode.getValue();
    var t = maketimer(time, func {
        controls.startEngine(0);
    });
    t.singleShot = 1;
    t.start();
});

# Dialogs

addcommand("fuel-and-payload-dialog", func {gui.showWeightDialog();});
addcommand("livery-dialog", func {aircraft.livery.dialog.open();});

addcommand("refuelling-dialog", func {
    if (!getprop("engines/engine/running"))
        RefuellingDialog.new().show();
    else
        gui.showWeightDialog();
});

# Fuel Tanks

addcommand("tank-select-off", func {select_fuel_tank(Tank.OFF);});
addcommand("tank-select-left", func {select_fuel_tank(Tank.LEFT);});
addcommand("tank-select-right", func {select_fuel_tank(Tank.RIGHT);});
addcommand("tank-select-both", func {select_fuel_tank(Tank.BOTH);});

# Magnetos

addcommand("magnetos-off", func {select_magnetos(Magnetos.OFF);});
addcommand("magnetos-left", func {select_magnetos(Magnetos.LEFT);});
addcommand("magnetos-right", func {select_magnetos(Magnetos.RIGHT);});
addcommand("magnetos-both", func {select_magnetos(Magnetos.BOTH);});

# Taxi/Land

addcommand("land-taxi-off", func {select_landtaxi(LandTaxi.OFF);});
addcommand("land-taxi-taxi", func {select_landtaxi(LandTaxi.TAXI);});
addcommand("land-taxi-land", func {select_landtaxi(LandTaxi.LAND);});

# Starter
addcommand("engage-starter", func {controls.startEngine(1);});
addcommand("release-starter", func {controls.startEngine(0);});

# Switches

addcommand("switch-adjust", func(node) {switch("property-adjust", node);});
addcommand("switch-assign", func(node) {switch("property-assign", node);});
addcommand("switch-toggle", func(node) {switch("property-toggle", node);});

addcommand("switch-check", func(node) {
    fgcommand("property-toggle", node);
    var t = maketimer(1.0, func {
        switch("property-toggle", node);
    });
    t.singleShot = 1;
    t.start();
});

addcommand("switch-momentary", func(node) {
    fgcommand("property-toggle", node);
    var t = maketimer(0.1, func {
        switch("property-toggle", node);
    });
    t.singleShot = 1;
    t.start();
});

printlog("info", "Nasal listeners and commands loaded");
