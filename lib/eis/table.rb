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
      @data = []
    end

    def to_s
      "Table of #{@elf}, located at #{@location} with #{@count} entries about #{@type}"
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

    ##
    # = Change the Location that the Table Located
    # This method will change the value of field +@location+.
    # Usful when you want to auto-reallocate the table(s).
    #
    # == Parameters
    # +loc+::    The new loacation the table should be located.
    # +is_vma+:: _named_ Is the +loc+ is vma? DEFAULT: true.
    def change_loc! loc, is_vma: true
      @location = is_vma ? @elf.vma_to_loc(loc) : loc
    end

    attr_reader :location, :count, :type

    Cell = Struct.new :location, :index, :data

    ##
    # Read table contents from specified ElfMan
    #
    # == Code Block
    # A block with one parameter which recieve the read
    # ENTRY datum instance.
    def read
      # loc = @elf.vma_to_loc @location
      @data = []

      @elf.base_stream.seek @location
      i = 0
      @count.times do
        puts("Table#read(): will read at #{@elf.base_stream.pos.to_s(16)}") if EIS::Core.eis_debug
        cell = Cell.new @elf.base_stream.pos, i.to_s
        begin
          inst = @type.new
          inst.read(@elf.base_stream)
        rescue RangeError
          # raise "Table#read(): fatal: pointer error. @#{i}"
          warn "#{self}:\n\tFatal when read #{i}: bad pointer. Table cutted."
          @count = i
          return
          # rescue StandardException => e
          #   warn "#{self}:\n\tUnknown error, can't recover."
          #   raise e
        end
        puts("Table#read(): read #{inst}") if EIS::Core.eis_debug
        cell.data = inst
        @data << cell
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

    def each_data
      if block_given?
        @data.each do |e|
          yield e.data
        end
      end
    end

    def each_index
      if block_given?
        @data.each do |e|
          yield e.index
        end
      end
    end

    ##
    # Call the given block for each ref in the table.
    # Including the refs in every BinStruct's instances.
    def each_ref
      if block_given?
        each_data do |e|
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

    ##
    # Get first datum that exists on given location.
    def datum_by_location loc
      @data.each do |datum|
        return datum if datum.location == loc
      end
      nil
    end

    ##
    # Get first datum that holds the given index.
    def datum_by_index idx
      @data.each do |datum|
        return datum if datum.index == idx
      end
      nil
    end

    ##
    # Get all data that exists on given location.
    def data_by_location loc
      ret = []
      @data.each do |datum|
        ret << datum if datum.location == loc
      end
      ret
    end

    ##
    # Get all data the holds the given index.
    #
    # *testonly*: the result should be only ONE element if other routine
    # is running correctly. **Prevent** using this and try to using
    # <tt>datum_by_index(idx)</tt>.
    def data_by_index idx
      ret = []
      @data.each do |datum|
        ret << datum if datum.index == idx
      end
      ret
    end

    ##
    # = Update table data by Hash
    # This method accept a Hash about a map from string to data object.
    # It will **drop** old data and refill with given data.
    # Each datum holds a key of string about its index, and a value of
    # data object which will be the data stored in.
    #
    # == Parameters
    # +data+:: The data Hash which holds the structure described before.
    def update_data! data
      loc = @location
      @data.clear
      data.each do |index, datum|
        @data << Cell.new(loc, index.to_s, datum)
      end
    end

    attr_reader :data

    ##
    # Set data to this table. If the data size is mismatch
    # with the recored size, raise ArgumentError.
    def data=(value)
      raise ArgumentError.new "value", "Type error, must be an Array. But #{value.class}" unless value.is_a? Array
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

      each_data do |datum|
        datum.write(@elf.elf_out)
      end
    end
  end
end
