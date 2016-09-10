module ChipGPIO
  module Pin
    class Pin
      attr_reader :gpio_number

      def initialize(gpio_number)
        @gpio_number = gpio_number
        @base_path = "/sys/class/gpio/gpio#{@gpio_number}"
      end

      def available?
        return File.exist?(@base_path)
      end

      def export
        File.open("/sys/class/gpio/export", "w") { |f| f.write(@gpio_number.to_s) }
      end

      def unexport
        File.open("/sys/class/gpio/unexport", "w") { |f| f.write(@gpio_number.to_s) }
      end

      def direction
        v = File.read("#{@base_path}/direction").strip
        case v
        when "in"
          return :input
        when "out"
          return :output
        else
          throw "Unexpected direction #{v}"
        end
      end

      def direction=(d)
        case d
        when :input
          v = "in"
        when :output
          v = "out"
        else
          throw "Unexpected direction: #{d}; must be :input or :output"
        end

        File.open("#{@base_path}/direction", "w") { |f| f.write(v) }
      end

      def value
        throw "Pin is not currently available" if !self.available?

        v = File.read("#{@base_path}/value")
        #assume that values will always be numeric
        match = /([0-9]+)/.match(v)

        return 0 if match.nil? 
        return 0 if match.captures.size == 0
        return match.captures[0].to_i
      end

      def value=(v)
        throw "Pin is not currently available" if !self.available?

        v = v.to_s
        File.open("#{@base_path}/value", "w") { |f| f.write(v) }
      end
    end

  end

  def self.get_xio_base
    labels = Dir::glob("/sys/class/gpio/*/label")
    labels.each do |label|
      value = File.read(label).strip
      if value == "pcf8574a"
        base_path = File.dirname(label)
        base_path = File.join(base_path, 'base')
        base = File.read(base_path).strip
        return base.to_i
      end
    end

    throw "Could not find XIO base"
  end

  def self.get_pins
      cis = [132, 133, 134, 135, 136, 137, 138, 139 ]
      xio = []

      xio_base = get_xio_base()
      (0..7).each { |i| xio << (xio_base + i) }
      
      pins = {}

      cis.each_with_index { |gpio, index| pins["CSI#{index}".to_sym] = Pin::Pin.new(gpio) }
      xio.each_with_index { |gpio, index| pins["XIO#{index}".to_sym] = Pin::Pin.new(gpio) }

      return pins
  end
end