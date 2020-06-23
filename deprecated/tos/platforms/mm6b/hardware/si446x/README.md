The Silicon Labs Si446x Sub-gigahertz radios have a wide range
of operating modes and features. This driver is designed to
mainly work with the Si4468, although it should work with the
Si4463 as well if '68 chip specific features are avoided (like
Preamble sense mode, which were new hardware features).

The majority of the radio configuration is set through
property groups, consisting of a dozen or so groups
containing 4 to 80 bytes of property bytes. Radio
set_property and get_property operations provide the
means to change and read these property settings.

In addition, radio configuration is also found in some
other commands such as the POWER_UP command which contains
the crystal frequency or SET_GPIO_CTL command which
determines the radio function assigned to the its GPIO
pins, like CTS, RX, TX, and SLEEP.

The complexity of this chip and the proprietary nature of
the code enforces a dependency the the Silicon Labs provided
configuration tool, called WDS. This program is provided by
SI in conjunction with their evaluation board and as such
demonstrates chip features the code it generates. Most of
this code is not used in our application, but typically one
or two files from the generated source are important. This
includes a file containing configuration strings for the
saved configuration. An optional second file containing a
patch file may also be provided.

In order to enable code sharing between the MSP432 Tag
program and the Raspberry Pi Basestation program, a code
generation tool is provided that takes the output produced
by the WDS program and generates the necessary .h and .c
files used by the Tag and RPi. See 'wds_prep.py' for details.

Care needs to be taken in the use of these generated
configurations because in some cases there are code
dependencies that the software needs to provide in order to
make use of them.

Some of the dependencies involve chip configuration. For
instance, if there is an optional patch file provided, it
needs to be loaded immediately after the chip is enabled and
before the power-on command. This means features like using
chip GPIO pins has to wait until after the patch has been
loaded. For instance, use of the clear-to-send (CTS) signal
is based on configurating a GPIO pin. Until this is done,
the software based CTS check (read command buffer) needs
to be performed.

Other program features may depend on specific
characteristics of the configuration file, like bit rate
for determining timeouts. Metadata found in the WDS
radio_config.h file is converted to a dictionary associated
with each configuration file which includes values like bit
rate, radio frequency, crystal frequency, and freq deviation.
The program can access this metadata, along with the
configuration data, through a set of functions provided
by the code generator.

Configuration data is generally divided into three groups,
(1) WDS generated configuration, (2) device specific
configuration for features used by the program, and (3)
platform dependent configuration.

The WDS generated configuration is taken exactly as
produced and written as the first data to configure the
chip. Following this, platform specific and device
specific code is written to the chip possibly overwriting
an earlier write. This is expected and final chip state
should be valdiated by dumping all group and device
registers for comparison.

Unfortunately the WDS program does not allow selection
of all configuration parameters required by our usage.
Therefore, the process of setting radio properties starts
with all of the WDS provided pstrings followed by any
device driver specific settings. The POWER_ON and
SET_GPIO_CTL are handled specially in the program
startup of the chip.

The configuration is maintained in a set of arrays
containing pstrings. A pstring, named by its definition
in Pascal, consists of the first byte providing
a length followed by n bytes of data. The bytes
of data are written into the command buffer of the
chip and represent the set of commands used for
configuration.

Below is the list of files that are required for
configuring the Si446x radio.


## Required Files

    - mm/tos/chips/si446x/
      - {Si446xConfigDevice.h,si446x.h,si446xRadio.h,si446xWDS_*.h}

    - mm/tos/platform/{dev6a,mm6a}/hardware/si446x/
      - {RadioConfig.h, Si446xConfigPlatform.h}

# Configuration related details:

### In directory tos/chips/si446x

    - Si446xConfigDevice.h (formerly Si446xLocalConfig.h)
      - provides the configuration pstring array si446x_device_config[]
        - radio configuration pstrings required by this driver for
          fifo size (46/129) and thresholds, interrupt sources,
          packet rx and tx handling, modem RSSI control, preamble,
          and tx power level.
      - includes the platform configuration pstrings as part of
        the device configuration pstring array (at the beginning)

    - WDS-files/*.{c,h}  [generated code]
      - several alternative radio config files found in this directory
      - each provides an alternate si446x_wds_config[]
        - radio configuration pstrings generated by the WDS program
      - the code generator produces the additional code needed to
        reference each of the individual configurations

    - WDS-files/wds_prep.p [copy of code generator]
      - code generator that processes WDS output for program
        inclusion

    - si446x.h
      - common radio chip low level definitions

    - Si446xCmdP.nc
      - provides
        - uint8_t **get_config_lists()
        - const uint8_t *config_list[] = {si446x_wds_config, si446x_device_config, NULL};
      - uses config files
        - RadioConfig.h
        - si446x.h
        - wds_configs.h
      - uses wds_config_select() to choose the selected config
        - note that the default can be changed at runtime by
          setting program variables. See wds_config.c for specifics.

    - Si446xRadio.h
      - radio packet format definition


### In directory tos/platforms/{dev6a,mm6a}/hardware/si446x

    - RadioConfig.h
      - includes
        - Si446xConfigPlatform.h
        - Si446xConfigDevice.h
      - used by
        - Si446xDriverLayerC.nc (for TRadio typedef)
        - Si446xCmdP.nc (for radio config pstrings)

    - Si446xConfigPlatform.h
      - radio configuration pstrings required by the platform
      - currently has only one command to set the GPIO pin
        configuration

    - wds_config.c [generated code]
      - wds_radio_configs[] array holds pointers to all
        of the configurations, including its name, metadata
        and configuration pstrings
      - functions for accessing the configurations, including
        examining what is in the list, selecting one as the
        default and getting information on the default (name,
        metadata, pstrings).

    - wds_config.h [generated code]
      - structure used to access configuration metatdata
      - configuration accessor function extern declarations
