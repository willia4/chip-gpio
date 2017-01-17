# chip-gpio

A ruby gem for controlling the IO hardware on a $9 CHIP computer. 

Can currently set output values and read input values from GPIO pins on CHIP computers running v4.3 or v4.4 images. 

Supports a software SPI mode using the GPIO pins. This support is incomplete. See the TODO 
in `SoftSpi.rb`. 

## Installation

    gem install chip-gpio

## Examples

### Initialize

    require 'chip-gpio'
    pins = ChipGPIO.get_pins

### Export pins

    pins[:XIO7].available? 
    => false

    pins[:XIO7].export
    pins[:XIO7].available? 
    => true

### Set a value

    pins[:XIO7].direction = :output
    pins[:XIO7].value = 1
    pins[:XIO7].value
    => 1

### Read a value

	pins[:XIO7].direction = :output
	pins[:XIO7].value
    => 1	