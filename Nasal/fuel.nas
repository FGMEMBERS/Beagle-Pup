################################################################################
#
# Beagle Pup Fuel System Helpers
#
# Copyright (c) 2015 Richard Senior
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

################################################################################
# Aircraft Fuel System
################################################################################

var _lock = 0;

var Tank = {OFF: 0, LEFT: 1, BOTH: 2, RIGHT: 3};

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

# Select a position on the fuel tank selector
#
var select_fuel_tank = func(n)
{
    var s = getprop("controls/fuel/tank-selector");
    var steps = abs(n - s);
    multi_click(steps == 3 ? 1 : steps);
    setprop("controls/fuel/tank-selector", n);
}

# Infer the position of the fuel tank selector from the checkboxes in the 
# fuel and payload dialog
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

var start_listeners = func()
{
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

    # Update the fuel selection from the fuel and payload dialog (left tank)
    #
    setlistener("consumables/fuel/tank[1]/selected", func(node) {
        lock(func {
            infer_fuel_tank_selector();
        });
    }, startup = 1, runtime = 0);

    # Update the fuel selection from the fuel and payload dialog (right tank)
    #
    setlistener("consumables/fuel/tank[2]/selected", func(node) {
        lock(func {
            infer_fuel_tank_selector();
        });
    }, startup = 1, runtime = 0);
}

setlistener("sim/signals/fdm-initialized", start_listeners, 0, 0);

################################################################################
# Refuelling Dialog
################################################################################

var Wing = {Left: 1, Right: 2};

var RefuellingController = {

    _totalFuelProperty: "consumables/fuel/total-fuel-gal_imp",
    _leftFillProperty: "fdm/jsbsim/propulsion/tank[1]/fill",
    _leftPctFullProperty: "fdm/jsbsim/propulsion/tank[1]/pct-full",
    _rightFillProperty: "fdm/jsbsim/propulsion/tank[2]/fill",
    _rightPctFullProperty: "fdm/jsbsim/propulsion/tank[2]/pct-full",

    new: func {
        var m = {
            parents: [RefuellingController]
        };
        return m;
    },

    isFull: func(tank) {
        var pctFull = getprop(tank == Wing.Left ? me._leftPctFullProperty : me._rightPctFullProperty);
        return pctFull >= 100;
    },

    isFilling: func {
        return me.getFilling(Wing.Left) or me.getFilling(Wing.Right);
    },

    getFilling: func(tank) {
        return getprop(tank == Wing.Left ? me._leftFillProperty : me._rightFillProperty);
    },

    setFilling: func(tank, filling) {
        setprop(tank == Wing.Left ? me._leftFillProperty : me._rightFillProperty, filling);
        if (filling) {
            # Stop filling the other tank
            setprop(tank == Wing.Left ? me._rightFillProperty : me._leftFillProperty, 0);
        }
    },

    quantity: func {
        return getprop(me._totalFuelProperty) - me._initialFuel;
    },

    reset: func {
        me.setFilling(Wing.Left, 0);
        me.setFilling(Wing.Right, 0);
        me._initialFuel = getprop(me._totalFuelProperty);
    }

};

var RefuellingDialog = {

    _width: 240,
    _height: 240,

    _leftButton: nil,
    _rightButton: nil,
    _quantityLabel: nil,
    _fillingLamp: nil,
    _timer: nil,

    new: func (title="Refuelling") {
        var m = {
            parents: [RefuellingDialog]
        };
        m._title = title;
        m._controller = RefuellingController.new();
        return m;
    },

    show: func {
        me._controller.reset();

        var window = canvas.Window.new([me._width, me._height], "Refuelling")
            .set("title", me._title);
        window.owner = me;

        var dialog = window.createCanvas();
        var root = dialog.createGroup();

        var svg = root.createChild("group");
        canvas.parsesvg(svg, "Aircraft/Beagle-Pup/Nasal/fuel.svg");
        me._quantityLabel = svg.getElementById("quantityLabel");
        me._fillingLamp = svg.getElementById("fillingLamp");

        me._leftButton = canvas.gui.widgets.Button.new(root, canvas.style, {})
            .setText("Left")
            .setCheckable(1)
            .setChecked(0)
            .setFixedSize(60, 30);

        me._rightButton = canvas.gui.widgets.Button.new(root, canvas.style, {})
            .setText("Right")
            .setCheckable(1)
            .setChecked(0)
            .setFixedSize(60, 30);

        var vbox = canvas.VBoxLayout.new();
        dialog.setLayout(vbox);
        vbox.addStretch();

        var hbox = canvas.HBoxLayout.new();
        vbox.addItem(hbox);
        hbox.setContentsMargin(20);
        hbox.addItem(me._leftButton);
        hbox.addItem(me._rightButton);

        me._leftButton.listen("toggled", func(l) {
            me._controller.setFilling(Wing.Left, l.detail.checked);
        });

        me._rightButton.listen("toggled", func(r) {
            me._controller.setFilling(Wing.Right, r.detail.checked);
        });

        window.del = func {
            me.owner.cleanup();
            call(canvas.Window.del, [], me);
        }

        me._timer = maketimer(0, func { me.update() });
        me._timer.start();
    },

    update: func() {
        # Automatic stop
        if (me._controller.isFull(Wing.Left))
            me._controller.setFilling(Wing.Left, 0);
        if (me._controller.isFull(Wing.Right))
            me._controller.setFilling(Wing.Right, 0);

        me._quantityLabel.setText(sprintf("%0.01f", me._controller.quantity()));
        me._leftButton.setChecked(me._controller.getFilling(Wing.Left));
        me._rightButton.setChecked(me._controller.getFilling(Wing.Right));
        me._fillingLamp.setVisible(me._controller.isFilling());
    },

    cleanup: func {
        if (me._timer != nil)
            me._timer.stop();
        me._controller.setFilling(Wing.Left, 0);
        me._controller.setFilling(Wing.Right, 0);
    },

};

print("Fuel system loaded");
