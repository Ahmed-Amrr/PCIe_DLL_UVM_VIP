`ifndef PCIE_FEATURE_RESERVED_SEQUENCE_SV
`define PCIE_FEATURE_RESERVED_SEQUENCE_SV

  class pcie_feature_reserved_sequence extends pcie_base_seq;
      `uvm_object_utils(pcie_feature_reserved_sequence)

      pcie_dllp_seq_item item;
     
      function new(string name = "pcie_feature_reserved_sequence");
          super.new(name);
      endfunction : new

      virtual task body();
        int i = 0 ;
          `uvm_info(get_type_name(), "Starting Feature Exchange Sequence", UVM_LOW)

          super.start_from_Feature(item);

          while (p_sequencer.state == DL_FEATURE) begin
            item = pcie_dllp_seq_item::type_id::create("item");
            start_item(item);
              item.dllp[47:40] = FEATURE; 
              item.dllp[38:16] = $random();
              // We mirror the remote valid bit back as our Ack
              item.dllp[39]    = cfg.remote_register_feature.remote_feature_valid;
            finish_item(item);

            i++;
            // Counter to count Timeout for each state in order not to stuck 
            if (i == 100) begin
              `uvm_error(get_type_name(), "Timeout for the base seq in DL_FEATURE state")
              break;
            end
          end

          `uvm_info(get_type_name(), "Feature Exchange Sequence Finished", UVM_LOW)
      endtask : body

  endclass 



`endif