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

  def self.chip_version
    default_version = :v4_4

    begin
      version_string = File.read('/proc/version')

      #grab the major and minor version of the Linux string; only match on NTC versions
      #since custom builds will be weird
      match = /Linux version ([0-9]+)\.([0-9]+).+-ntc.*/.match(version_string)
      throw "Unable to parse /proc/version string" if match.nil? 
      throw "Unable to parse /proc/version string - could not find version numbers" if match.captures.size != 2

      major = match.captures[0]
      minor = match.captures[1]

      if major == "4" && minor == "3" 
        return :v4_3
      elsif  major== "4" && minor == "4"
        return :v4_4
      else
        throw "Unrecognized version #{major}.#{minor}"
      end
    rescue
      puts "Unable to read version from /proc/version; using #{default_version} as default"
      version = default_version
    end

    return version
  end

  def self.get_pins
      v = chip_version
      cis = [132, 133, 134, 135, 136, 137, 138, 139 ]

      case chip_version
      when :v4_3
        xio = [408, 409, 410, 411, 412, 413, 414, 415]
      when :v4_4
        xio = [1016, 1017, 1018, 1019, 1020, 1021, 1022, 1023]
      end

      pins = {}

      cis.each_with_index { |gpio, index| pins["CSI#{index}".to_sym] = Pin::Pin.new(gpio) }
      xio.each_with_index { |gpio, index| pins["XIO#{index}".to_sym] = Pin::Pin.new(gpio) }

      return pins
  end
end