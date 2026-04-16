`ifndef PCIE_FEATURE_SEQUENCE_SV
`define PCIE_FEATURE_SEQUENCE_SV

  class pcie_feature_sequence extends pcie_base_seq;
      `uvm_object_utils(pcie_feature_sequence)

      pcie_dllp_seq_item item;
      pcie_vip_config cfg;
     
      function new(string name = "pcie_feature_sequence");
          super.new(name);
      endfunction : new

      virtual task body();
        int i = 0;
          `uvm_info(get_type_name(), "Starting Feature Exchange Sequence", UVM_LOW)

          start_from_Feature(item);
          while (p_sequencer.state == DL_FEATURE) begin
            send_feat_dllp(FEATURE, item);
            i++;
            // Counter to count Timeout for each state in order not to stuck 
            if (i == 1000) begin
              `uvm_error(get_type_name(), "Timeout for the seq in DL_FEATURE state")
              break;
            end
          end

          `uvm_info(get_type_name(), "Feature Exchange Sequence Finished", UVM_LOW)
      endtask : body

  endclass : pcie_feature_sequence



`endif // PCIE_FEATURE_SEQUENCE_SV