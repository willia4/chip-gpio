# Ported from https://github.com/adafruit/circuitpython/blob/master/shared-module/bitbangio/SPI.c
#
# The MIT License (MIT)
#
# Copyright (c) 2013, 2014 Damien P. George
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in

# *** TODO
# ***   Reads
# ***   Baudrate
# ***   Phase 

module ChipGPIO
  class SoftSPI
    attr_reader :clock_pin
    attr_reader :input_pin
    attr_reader :output_pin

    attr_reader :polarity
    attr_reader :phase
    attr_reader :word_size

    def initialize(clock_pin: nil, input_pin: nil, output_pin: nil, polarity: 1, phase: 0, word_size: 8)
      raise ArgumentError, "clock_pin is required" if clock_pin == nil
      raise ArgumentError, "At least input_pin or output_pin must be specified" if ((input_pin == nil) && (output_pin == nil))

      raise ArgumentError, "polarity must be either 0 or 1" if ((polarity != 0) && (polarity != 1))
      raise ArgumentError, "phase must be either 0 or 1" if ((phase != 0) && (phase != 1))

      pins = ChipGPIO.get_pins()

      @clock_pin = nil
      @input_pin = nil
      @output_pin = nil

      @clock_pin = pins[clock_pin]
      @input_pin = pins[input_pin] if (input_pin)
      @output_pin = pins[output_pin] if (output_pin)

      @clock_pin.export if not @clock_pin.available?
      @input_pin.export if input_pin && (not @input_pin.available?)
      @output_pin.export if output_pin && (not @output_pin.available?)

      @clock_pin.direction = :output
      @input_pin.direction = :output if (input_pin)
      @output_pin.direction = :output if (output_pin)

      @clock_pin.value = 0
      @input_pin.value = 0 if (input_pin)
      @output_pin.value = 0 if (output_pin)

      @polarity = polarity
      @phase = phase
      @word_size = word_size
    end

    def max_word
      ((2**@word_size) - 1)
    end

    def write(words: [], reverse_output: true)
      raise "An output_pin must be specified to write" if !@output_pin

      bits = Array (0..(@word_size - 1))

      if reverse_output
        words = words.reverse() 
        bits = bits.reverse() 
      end
      
      words.each do |w|
        w = 0 if w < 0
        w = max_word if w > max_word 

        bits.each do |b|
          @clock_pin.value = (1 - @polarity)

          if (w & (1 << b)) > 0
            @output_pin.value = 1
          else
            @output_pin.value = 0
          end

          @clock_pin.value = @polarity
        end

        @clock_pin.value = (1 - @polarity)
      end
    end
  end
end
