module EIS
  ##
  # Table is a class to record where and how large a structure array is.
  #
  # = Purpose
  # * Record the position (and the size) of a structure
  # * Provides convinient methods to extract this structure array
  # * Provides enough free space so that user can change it's behavior
  #
  # = Example
  # <tt>tbl = Table.new 0x2ff59d3, 32, Dialog
  # tbl.elf = elf # these two lines are equal to elf.new_table 0x2ff59d3, 32, Dialog
  # tbl.extract do |entry|
  #   puts entry.id, entry.text
  # end
  #
  # tbl.each do |entry|
  #   entry.id = 5 if entry.text == 'Set up.'
  # end
  #
  # outelf = File.new('./output.elf', 'wb')
  # elf.output = outelf
  # tbl.write #this action will sync the modifications to elf output stream</tt>
  class Table
    ##
    # Create a new table instance
    #
    # = Parameters
    # +location+::  +Number+ A number to record where the table located.
    # +count+::     +Number+ How many entries this table contains.
    # +type+::      +EIS::BinStruct+ The type of entry.
    def initialize(location, count, type, elf_man)
      @location = location
      @count = count
      @type = type
      @elf = elf_man
    end

    attr_reader :location, :count

    ##
    # Read table contant from specified ElfMan
    #
    # = Code Block
    # A block with one parameter which recieve the read
    # ENTRY datum instance.
    def read
      loc = @elf.vma_to_loc @location
      @data = []

      @elf.base_stream.seek loc
      i = 0
      @count.times do
        begin
          inst = @type.new
          inst.read(@elf.base_stream)
        rescue Errno::EINVAL
          raise "Table#read(): fatal: seek failed. @#{i}"
        end
        puts("Table#read(): read #{inst}") if $eis_debug
        @data << inst
        i += 1
        yield(inst) if block_given?
      end
    end

    attr_reader :data

    def data=(value)
      raise ArgumentError.new "value", "Size error. (#{value.size} against #{@count})" if value.size != @count

      @data = value
    end

    def set_data!(value)
      @data = value
    end

    ##
    # Write table contents to specified ElfMan
    def write
      raise ArgumentError.new("elfman", "#{@elf.class} against to EIS::ElfMan") if @elf.class != ElfMan

      loc = @elf.vma_to_loc @location
      @elf.elf_out.seek loc

      @data.each do |datum|
        datum.write(@elf.elf_out)
      end
    end
  end
end
