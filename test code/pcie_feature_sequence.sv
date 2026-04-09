`ifndef PCIE_FEATURE_SEQUENCE_SV
`define PCIE_FEATURE_SEQUENCE_SV

class pcie_feature_sequence extends pcie_base_sequence;
    `uvm_object_utils(pcie_feature_sequence)

    pcie_dllp_seq_item item;
    pcie_vip_config cfg;
   
    function new(string name = "pcie_feature_sequence");
        super.new(name);
    endfunction : new

    virtual task body();
      int i;
        `uvm_info(get_type_name(), "Starting Feature Exchange Sequence", UVM_LOW)

        start_from_Feature(item);
        while (p_sequencer.state == DL_FEATURE) begin
          send_feat_dllp(FEATURE);
          i++;
          // Counter to count Timeout for each state in order not to stuck 
          if (i == 1000) begin
            `uvm_error("Base Seq", "Timeout for the base seq in DL_FEATURE state")
            break;
          end
        end

        `uvm_info(get_type_name(), "Feature Exchange Sequence Finished", UVM_LOW)
    endtask : body

    // send_fc_dllp
    task send_feat_dllp (input dllp_type_t pkt_type);
        item = pcie_dllp_seq_item::type_id::create("item");
        start_item(item);
        item.dllp[47:40] = pkt_type; 
        item.dllp[38:16] = cfg.local_register_feature.local_feature_supported;
        // We mirror the remote valid bit back as our Ack
        item.dllp[39]    = cfg.remote_register_feature.remote_feature_valid;
        finish_item(item);
    endtask : send_feat_dllp

endclass : pcie_feature_sequence



`endif // PCIE_FEATURE_SEQUENCE_SV