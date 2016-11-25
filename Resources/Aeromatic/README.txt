Aeromatic Parameter Files

The parameter files in this directory were used to create the initial
configuration of FDM for each Pup model. To accomodate the three models,
the overall structure was changed significantly and the following parts
have been altered from the generated files:

pup-flight-control.xml
pup-ground-reactions.xml

The main configuration file for each aircraft (pup100.xml, etc), provides
the structure for multiple aircraft variants but the header and metrics
sections are copied from the Aeromatic configuration. The centre of
gravity, aero reference point and pointmasses have been customized.

The bulk of the aerodynamic model in pup-aerodynamics.xml is a copy
of the <aerodynamics> section, with some edits.

In addition, propeller models have been created using JavaProp analysis
and the engine files created from scratch. See the Resources/JavaProp
directory for JavaProp inputs and outputs.

