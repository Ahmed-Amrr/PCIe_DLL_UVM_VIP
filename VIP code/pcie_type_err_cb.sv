`ifndef PCIE_DLLP_TYPE_ERR_CB_SV
`define PCIE_DLLP_TYPE_ERR_CB_SV

class pcie_dllp_type_err_cb extends pcie_vip_driver_cb;
    `uvm_object_utils(pcie_dllp_type_err_cb)


    function new(string name = "pcie_dllp_type_err_cb");
        super.new(name);
    endfunction : new

    virtual task pre_drive(pcie_dllp_seq_item item, pcie_vip_tx_sequencer sqr);

        dllp_type_t wrong_type;

        if (sqr = null) begin
            `uvm_warning("CB_DLLP_TYPE", "sqr is null")
            return;
        end

        case (sqr.state)
            DL_FEATURE : begin
                randcase
                    1 : wrong_type = INITFC1_P;
                    1 : wrong_type = INITFC1_NP;
                    1 : wrong_type = INITFC1_CPL;
                    1 : wrong_type = INITFC2_P;
                    1 : wrong_type = INITFC2_NP;
                    1 : wrong_type = INITFC2_CPL;
                    1 : wrong_type = UPDATEFC_P;
                    1 : wrong_type = UPDATEFC_NP;
                    1 : wrong_type = UPDATEFC_CPL;
                    
                endcase
            end
            DL_INIT1 : begin
                randcase
                    1 : wrong_type = FEATURE;
                    1 : wrong_type = INITFC2_P;
                    1 : wrong_type = INITFC2_NP;
                    1 : wrong_type = INITFC2_CPL;
                    1 : wrong_type = UPDATEFC_P;
                    1 : wrong_type = UPDATEFC_NP;
                    1 : wrong_type = UPDATEFC_CPL;
                endcase
            end
            DL_INIT2 : begin
                randcase
                    1 : wrong_type = FEATURE;
                    1 : wrong_type = INITFC1_P;
                    1 : wrong_type = INITFC1_NP;
                    1 : wrong_type = INITFC1_CPL;
                    1 : wrong_type = UPDATEFC_P;
                    1 : wrong_type = UPDATEFC_NP;
                    1 : wrong_type = UPDATEFC_CPL;
                endcase
            end
            DL_ACTIVE : begin
                randcase
                    1 : wrong_type = FEATURE;
                    1 : wrong_type = INITFC1_P;
                    1 : wrong_type = INITFC1_NP;
                    1 : wrong_type = INITFC1_CPL;
                    1 : wrong_type = INITFC2_P;
                    1 : wrong_type = INITFC2_NP;
                    1 : wrong_type = INITFC2_CPL;
                endcase
            end
            DL_INACTIVE : begin
                randcase
                    1 : wrong_type = ACK;
                    1 : wrong_type = NACK;
                    1 : wrong_type = NOP;
                    1 : wrong_type = FEATURE;
                    1 : wrong_type = INITFC1_P;
                    1 : wrong_type = INITFC1_NP;
                    1 : wrong_type = INITFC1_CPL;
                    1 : wrong_type = INITFC2_P;
                    1 : wrong_type = INITFC2_NP;
                    1 : wrong_type = INITFC2_CPL;
                    1 : wrong_type = UPDATEFC_P;
                    1 : wrong_type = UPDATEFC_NP;
                    1 : wrong_type = UPDATEFC_CPL;
                endcase
            end
        endcase        
        item.dllp[47:40] = wrong_type;

    endtask : pre_drive

endclass : pcie_dllp_type_err_cb

`endif