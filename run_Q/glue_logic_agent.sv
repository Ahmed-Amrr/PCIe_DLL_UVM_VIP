`ifndef GLUE_LOGIC_AGENT_SV
`define GLUE_LOGIC_AGENT_SV

    class glue_logic_agent extends uvm_agent;

        // UVM Factory register
        `uvm_component_utils(glue_logic_agent)

        // Create handles to all agent components
        glue_logic_driver  ds_driver ;
        glue_logic_driver  us_driver ;
        glue_logic_monitor ds_monitor;
        glue_logic_monitor us_monitor;

        //==========================================================
        // Constructor
        //==========================================================
        function new(string name = "glue_logic_agent", uvm_component parent = null);
            super.new(name, parent);
        endfunction : new

        //==========================================================
        // Build Phase - Create all components 
        //==========================================================
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ds_driver  = glue_logic_driver::type_id::create("ds_driver", this)  ;
            us_driver  = glue_logic_driver::type_id::create("us_driver", this)  ;
            ds_monitor = glue_logic_monitor::type_id::create("ds_monitor", this);
            us_monitor = glue_logic_monitor::type_id::create("us_monitor", this);

        endfunction : build_phase

        //==========================================================
        // Connect Phase - Connect the components together
        //==========================================================
        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase); 

            // Connect upstream monitor with downstream driver and vise vera
            ds_monitor.mon_ap.connect(us_driver.drv_ex);
            us_monitor.mon_ap.connect(ds_driver.drv_ex);
        endfunction : connect_phase

    endclass  : glue_logic_agent

`endif