module EIS
  ##
  # = SymbolMan
  # The symbols manager
  # = Purpose
  # For manage the table's address and corresponding naming
  class SymbolMan
    def initialize(elf_man)
      @symb = Hash.new(nil)
      @elf_man = elf_man
    end

    def reg_symb(location, tbl)
      @symb[location] = tbl
    end

    def get_addr(tbl)
      @elf_man.loc_to_vma @symb.index(tbl)
    end

    def get_loc(tbl)
      @symb.index(tbl)
    end

    def get_inst(addr)
      @symb[addr]
    end
  end
end
