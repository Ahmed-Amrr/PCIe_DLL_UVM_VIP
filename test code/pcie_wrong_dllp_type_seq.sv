`ifndef PCIE_WRONG_DLLP_TYPE
`define PCIE_WRONG_DLLP_TYPE

  class pcie_wrong_dllp_type_seq extends pcie_base_seq;
      `uvm_object_utils(pcie_wrong_dllp_type_seq)

      pcie_dllp_seq_item item;

      dllp_type_t type;
     
      function new(string name = "pcie_wrong_dllp_type_seq");
          super.new(name);
      endfunction : new

      virtual task body();
        int i = 0 ;
          `uvm_info(get_type_name(), "Starting Feature Exchange Sequence", UVM_LOW)

          super.start_from_INIT2(item);

          for (int i = 0; i < 100; i++) begin
            send_fc_dllp(INITFC1_P,   FC_POSTED);
            send_fc_dllp(INITFC1_NP,  FC_NON_POSTED);
            send_fc_dllp(INITFC1_CPL, FC_COMPLETION);
          end

          super.start_from_Feature(item);

          while (p_sequencer.state == DL_FEATURE) begin
            type = $random();
            send_feat_dllp(type);
            i++;
            // Counter to count Timeout for each state in order not to stuck 
            if (i == 100) begin
              `uvm_error("Base Seq", "Timeout for the base seq in DL_FEATURE state")
              break;
            end
          end    

      endtask : body

  endclass 

`endif