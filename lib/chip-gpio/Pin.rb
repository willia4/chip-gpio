require 'epoll'

module ChipGPIO
  module Pin
    class Pin
      attr_reader :gpio_number
      attr_reader :pin_name

      def initialize(gpio_number, pin_name)
        @gpio_number = gpio_number
        @pin_name = pin_name
        @base_path = "/sys/class/gpio/gpio#{@gpio_number}"

        @interrupt_thread = nil
        @stop_waiting = false 
        @stop_waiting_lock = Mutex.new 

        @interrupt_procs = []
        @interrupt_procs_lock = Mutex.new

        @interrupt_pipe_read, @interrupt_pipe_write = IO.pipe()
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

      def edge
        v = File.read("#{@base_path}/edge").strip
        case v
        when "both"
          return :both
        when "rising"
          return :rising
        when "falling"
          return :falling
        else
          throw "Unexpected edge #{v}"
        end
      end

      def edge=(e)
        case e
        when :both
          v = "both"
        when :rising
          v = "rising"
        when :falling
          v = "falling"
        else
          throw "Unexpected edge: #{e}; must be :both, :rising, or :falling"
        end

        File.open("#{@base_path}/edge", "w") { |f| f.write(v) }
      end

      def active_low
        v = File.read("#{@base_path}/active_low").strip
        case v
        when "0"
          return false
        when "1"
          return true
        else
          throw "Unexpectd active_low: #{v}"
        end
      end

      def active_low=(b)
        v = !!b ? "1" : "0"
        File.open("#{@base_path}/active_low", "w") { |f| f.write(v) }
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

      def on_interrupt(&proc)
        return if !proc 
        throw "Interrupt is only valid for input pins" if direction != :input
        
        @interrupt_procs_lock.synchronize { @interrupt_procs << proc  } 
          
        if !@interrupt_thread
          @interrupt_thread = Thread.new("#{@base_path}/value") do |pin_path|
            
            fd = open(pin_path, 'r')

            epoll = Epoll.create()
            epoll.add(fd, Epoll::PRI)
            epoll.add(@interrupt_pipe_read, Epoll::IN)

            #read the value once before polling 
            fd.seek(0)
            fd.read()

            while true 
              stop = false 
              @stop_waiting_lock.synchronize { stop = @stop_waiting }
              break if stop 

              evlist = epoll.wait()

              evlist.each do |ev|

                if ev.data.fileno == fd.fileno 
                  ev.data.seek(0)
                  value = ev.data.read().delete("\n")

                  procs = []
                  @interrupt_procs_lock.synchronize { procs = @interrupt_procs.dup() }    

                  procs.each { |p| p.call(value) }
                end
              end
            end
          end
        end
      end

      def cancel_interrupt()
        @stop_waiting_lock.synchronize { @stop_waiting = true  } 
        @interrupt_pipe_write.write("0")
        @interrupt_thread.join()
        @interrupt_thread = nil
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

      cis.each_with_index { |gpio, index| sym = "CSI#{index}".to_sym; pins[sym] = Pin::Pin.new(gpio, sym) }
      xio.each_with_index { |gpio, index| sym = "XIO#{index}".to_sym; pins[sym] = Pin::Pin.new(gpio, sym) }

      return pins
  end
end