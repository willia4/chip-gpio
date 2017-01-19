module ChipGPIO
  class HardwareSPI
    attr_reader :polarity
    attr_reader :phase
    attr_reader :word_size
    attr_reader :lsb_first
    attr_reader :mode
    attr_reader :speed_hz

    SPI_MAX_CHUNK_BYTES = 64

    SPI_IOC_RD_MODE = 0x80016b01
    SPI_IOC_WR_MODE = 0x40016b01
    SPI_IOC_RD_LSB_FIRST = 0x80016b02
    SPI_IOC_WR_LSB_FIRST = 0x40016b02
    SPI_IOC_RD_BITS_PER_WORD = 0x80016b03
    SPI_IOC_WR_BITS_PER_WORD = 0x40016b03
    SPI_IOC_RD_MAX_SPEED_HZ = 0x80046b04
    SPI_IOC_WR_MAX_SPEED_HZ = 0x40046b04
    SPI_IOC_RD_MODE32 = 0x80046b05
    SPI_IOC_WR_MODE32 = 0x40046b05

    SPI_IOC_MESSAGE_1 = 0x40206b00 #can only be used to send one spi_ioc_transfer struct at a time

    SPI_CPHA = 0x01
    SPI_CPOL = 0x02

    def initialize(polarity: 0, phase: 0, word_size: 8, lsb_first: false)
      @polarity = polarity
      @phase = phase
      @word_size = word_size
      @lsb_first = lsb_first
      @speed_hz = 1000000 #TODO Configurable parameter

      @device = open("/dev/spidev32766.0", File::RDWR)      

      @mode = 0
      @mode = @mode | 0x01 if (phase == 1)
      @mode = @mode | 0x02 if (polarity == 1)

      write_u8(SPI_IOC_WR_MODE, @mode)
      write_u8(SPI_IOC_WR_LSB_FIRST, (@lsb_first ? 1 : 0))
      write_u32(SPI_IOC_WR_MAX_SPEED_HZ, @speed_hz) 

    end

    def close()
      @device.close()
    end

    def read_u8(msg)
      value_packed = [0].pack("C")
      @device.ioctl(msg, value_packed)
      return value_packed.unpack("C")[0]
    end

    def write_u8(msg, value)
      value_packed = [value].pack("C")
      @device.ioctl(msg, value_packed)
    end

    def read_u32(msg)
      value_packed = [0].pack("L")
      @device.ioctl(msg, value_packed)
      return value_packed.unpack("L")[0]
    end

    def write_u32(msg, value)
      value_packed = [value].pack("L")
      @device.ioctl(msg, value_packed)
    end

    def break_words_into_nibbles(words: [])
      nibbles_per_word = @word_size / 4

      #for each word, output each nibble individually 
      #(shifting by 4 each time since a nibble is 4 bits)
      words.each do |w|
        
        #this is basically the reverse of nibbles_per_word.times
        #we reverse it because we want to start at the most-significant nibble
        #which will be shifted the most times
        #
        #since we want to end up at 0, subtract one from nibbles_per_word
        #so we don't get an extra
        (nibbles_per_word - 1).downto(0).each do |i|
          yield w, ((w >> (i * 4)) & 0xf)
        end
      end
    end

    def pack_words_into_bytes(words: [])
      nibbles_per_word = @word_size / 4

      bytes = []
      current_byte = 0
      new_byte = true 

      break_words_into_nibbles(words: words) do |current_word, current_nibble|
        if new_byte
          new_byte = false 
          current_byte = current_byte | (current_nibble << 4)
        else
          current_byte = current_byte | current_nibble
          
          bytes << current_byte
          current_byte = 0
          new_byte = true
        end
      end

      return bytes
    end

    def transfer_bytes(bytes: [])
      # http://stackoverflow.com/questions/11949538/pointers-to-buffer-in-ioctl-call
      raise "Too many bytes sent to transfer_bytes" if bytes.size > SPI_MAX_CHUNK_BYTES
      
      #begin spi_ioc_transfer struct (cat /usr/include/linux/spi/spidev.h)
      tx_buff = bytes.pack("C*")        
      rx_buff = (Array.new(bytes.size) { 0 }).pack("C*")       
      
      tx_buff_pointer = [tx_buff].pack("P").unpack("L!")[0]   #u64 (zero-extended pointer)
      rx_buff_pointer = [rx_buff].pack("P").unpack("L!")[0]   #u64 (zero-extended pointer)

      
      buff_len = bytes.size                                   #u32
      speed_hz = @speed_hz                                    #u32

      delay_usecs = 0                                         #u16
      bits_per_word = 8                                       #u8
      cs_change = 0                                           #u8
      tx_nbits = 0                                            #u8
      rx_nbits = 0                                            #u8
      pad = 0                                                 #u16

      struct_array = [tx_buff_pointer, rx_buff_pointer, buff_len, speed_hz, delay_usecs, bits_per_word, cs_change, tx_nbits, rx_nbits, pad]
      struct_packed = struct_array.pack("QQLLSCCCCS")
      #end spi_ioc_transfer struct

      @device.ioctl(SPI_IOC_MESSAGE_1, struct_packed)

      return rx_buff.unpack("C*")
    end

    def transfer_data(words: [])
      
      bytes_to_transfer = pack_words_into_bytes(words: words)

      result = []

      bytes_to_transfer.each_slice(SPI_MAX_CHUNK_BYTES) do |chunk_bytes|
        result = result + transfer_bytes(bytes: chunk_bytes)
      end

      return result
    end

    def test()
      words = []
      24.times { |i| words << 0 }

      transfer_data(words: words)
    end

    def to_s
      return "\#<ChipGPIO:HardwareSPI mode=#{@mode} device=#{@device.path} word_size=#{@word_size} lsb_first=#{@lsb_first}>"
    end
  end
end