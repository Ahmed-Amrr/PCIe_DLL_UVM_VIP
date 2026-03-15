class glue_logic_agent extends uvm_agent;

    `uvm_component_utils(glue_logic_agent)

    glue_logic_driver  ds_driver ;
    glue_logic_driver  us_driver ;
    glue_logic_monitor ds_monitor;
    glue_logic_monitor us_monitor;
    function new(string name = "glue_logic_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction //new()

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ds_driver  = glue_logic_driver::type_id::create("ds_driver", this);
        us_driver  = glue_logic_driver::type_id::create("us_driver", this);
        ds_monitor = glue_logic_monitor::type_id::create("ds_monitor", this);
        us_monitor = glue_logic_monitor::type_id::create("us_monitor", this);

    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase); 
        ds_monitor.mon_ap.connect(us_driver.fifo_mon.analysis_export);
        us_monitor.mon_ap.connect(ds_driver.fifo_mon.analysis_export);
    endfunction
endclass //glue_logic_agent extends uvm_agent