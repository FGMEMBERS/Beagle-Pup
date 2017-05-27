################################################################################
#
# Beagle Pup Refuelling Dialog
#
# Copyright (c) 2016 Richard Senior
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

var Wing = {Left: 1, Right: 2};

var RefuellingController = {

    _propulsion: props.globals.getNode("fdm/jsbsim/propulsion"),
    _totalFuelProperty: "consumables/fuel/total-fuel-gal_imp",

    new: func {
        var m = {
            parents: [RefuellingController]
        };
        m.setFilling(Wing.Left, 0);
        m.setFilling(Wing.Right, 0);
        m._initialFuel = getprop(m._totalFuelProperty);
        return m;
    },

    isFull: func(tank) {
        var tankNode = me._propulsion.getChild("tank", tank);
        return tankNode.getChild("pct-full").getValue() >= 100;
    },

    isFilling: func {
        return me.getFilling(Wing.Left) or me.getFilling(Wing.Right);
    },

    getFilling: func(tank) {
        var tankNode = me._propulsion.getChild("tank", tank);
        return tankNode.getChild("fill").getBoolValue();
    },

    setFilling: func(tank, filling) {
        var tankNode = me._propulsion.getChild("tank", tank);
        tankNode.getChild("fill").setValue(filling);
        if (filling) {
            # Stop filling the other tank
            var otherTank = tank == 1 ? 2 : 1;
            var otherNode = me._propulsion.getChild("tank", otherTank);
            otherNode.getChild("fill").setValue(0);
        }
    },

    quantity: func {
        return getprop(me._totalFuelProperty) - me._initialFuel;
    },

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
        return m;
    },

    show: func {
        me._controller = RefuellingController.new();

        var window = canvas.Window.new([me._width, me._height], "Refuelling");
        window.set("title", me._title);
        window.owner = me;

        var dialog = window.createCanvas();
        var root = dialog.createGroup();

        var svg = root.createChild("group");
        canvas.parsesvg(svg, "Aircraft/Beagle-Pup/Nasal/refuel.svg");
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
        me._controller = nil;
    },

};
