require "eis/ref"
require "eis/bin_struct"

module EIS
  ##
  # Table is a class to record where and how large a structure array is.
  #
  # == Purpose
  # * Record the position (and the size) of a structure
  # * Provides convenient methods to extract this structure array
  # * Provides enough free space so that user can change it's behavior
  #
  # == Example
  # <tt>tbl = Table.new 0x2ff59d3, 32, Dialog, elf
  # tbl.read do |entry|
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
    def initialize(location, count, type, elf_man, is_vma: true)
      raise ArgumentError.new("elf_man", "#{@elf.class} against to EIS::ElfMan") if elf_man.class != ElfMan

      @location = is_vma ? elf_man.vma_to_loc(location) : location
      @count = count
      @type = type
      @elf = elf_man
    end

    ##
    # Get the total size of this table.
    def size
      @type.size * @count
    end

    def eql? other
      other.location == @location && other.count == @count
    end

    def equal? other
      eql? other
    end

    def == other
      eql? other
    end

    attr_reader :location, :count

    ##
    # Read table contents from specified ElfMan
    #
    # = Code Block
    # A block with one parameter which recieve the read
    # ENTRY datum instance.
    def read
      # loc = @elf.vma_to_loc @location
      @data = []

      @elf.base_stream.seek @location
      i = 0
      @count.times do
        begin
          inst = @type.new
          inst.read(@elf.base_stream)
        rescue Errno::EINVAL
          raise "Table#read(): fatal: seek failed. @#{i}"
        end
        puts("Table#read(): read #{inst}") if EIS::Core.eis_debug
        @data << inst
        i += 1
        yield(inst) if block_given?
      end
    end

    def each
      if block_given?
        @data.each do |e|
          yield e
        end
      end
    end

    ##
    # Call the given block for each ref in the table.
    # Including the refs in every BinStruct's instances.
    def each_ref
      if block_given?
        @data.each do |e|
          if e.is_a? EIS::BinStruct
            e.each_ref do |ref|
              yield ref
            end
          elsif e.is_a? EIS::Ref
            yield e
          end
        end
      end
    end

    attr_reader :data

    ##
    # Set data to this table. If the data size is mismatch
    # with the recored size, raise ArgumentError.
    def data=(value)
      raise ArgumentError.new "value", "Size error. (#{value.size} against #{@count})" if value.size != @count

      @data = value
    end

    ##
    # Force the table accept the data whose size is not equal to
    # the recored size.
    # NOTE: Will not update size info in the same time.
    def set_data!(value)
      @data = value
    end

    ##
    # Write table contents to specified ElfMan
    def write
      # loc = @elf.vma_to_loc @location
      @elf.elf_out.seek @location

      @data.each do |datum|
        datum.write(@elf.elf_out)
      end
    end
  end
end
