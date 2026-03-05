 
// --------------------------------------  explicit predictor  --------------------------------------
 
 
 
 
`include "uvm_macros.svh"					// will give an access to uvm macros
import uvm_pkg::*;							// will give an access to uvm pkg(to all uvm classes)
 
 
// ------------------- transaction class ---------------------
 
 
class transaction extends uvm_sequence_item;
  `uvm_object_utils(transaction)
 
  	 bit[7:0] din;
	 bit      wr_enb;
	 bit      addr;
	 bit      rst;
 
 
	 bit[7:0] dout;

 
  	function new(input string name = "transaction");
    		super.new(name);
  	endfunction: new
endclass: transaction
 
 
 

// ------------------- driver class ---------------------
 
 
// driver class is also parameterize class
// component class in uvm base class hierarchy hence default constructor expecting two arguments.
// driver responsibility is to drive the stimulus from sequence to the DUT based upon the DUT's protocol and this
// responsibility is completely protocol dependent but in some cases driver is present & not driveing anythig just an idle 
// driver hence UVM_DEVELOPERS comes with common logic for this and its non_virtual in nature hence just need to
// extend this from uvm_driver.
// Access interface with config_db
 
// driver:- pkt(Stream of transactions) to pin level conversion
 
// in order to have a consistent TB execution flow,the UVM has a concept of phases to order the major steps that take place 
// during the simulution.
 
 
class driver extends uvm_driver #(transaction);
 
	
	virtual dut_interface vif;

 
  	`uvm_component_utils(driver)

  	function new(input string name = "driver", uvm_component parent = null);
    		super.new(name, parent);
  	endfunction: new
 
 
// build_phase:- responsible for building all lower level components
//		 executes in top down manner.	
 
 
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		req = transaction::type_id::create("req");					// req is an inbuild object of xtn type
		if(!uvm_config_db #(virtual dut_interface)::get(this, "", "virtual_intf", vif))	// hence no need to declare it
		`uvm_fatal(get_type_name(), "Unable to get virtual_intf vif")			// get can be return a bit type value 0 -> if failed 
	endfunction: build_phase										// 1 -> passed
 
  
 
 
// ----------------- reset dut task -----------------
 
 
	task reset_dut();
 
		@(posedge vif.clk);								// wait for one clk cycle
 
		vif.rst <= '1;
		vif.wr_enb <= '0;
		vif.din <= '0;
		vif.addr <= '0;
      repeat(5) @(posedge vif.clk);							// wait for 2 clk cycles
      `uvm_info(get_type_name(), "---- SYSTEM RESET ----", UVM_NONE)
 
		vif.rst <= '0;										// remove rst
 
	endtask: reset_dut 


// ------------- drive task ------------
 
	task drive();
 
		
		vif.rst <= '0;									// remove rst
		vif.wr_enb <= req.wr_enb;
		vif.addr <= req.addr;
 
		if(req.wr_enb) begin: B1						// if wr_enb is 1	
			vif.din <= req.din;							// apply the i/p to dut
          `uvm_info(get_type_name(), $sformatf(" DATA WRITE wr_data %0d", req.din), UVM_NONE)
 
          	repeat(3) @(posedge vif.clk);				// wait for 3 clk cycles
		end: B1
 
		else begin: B2									// else means !vif.wr_enb
 
			repeat(2) @(posedge vif.clk);				// wait for 2 clk cycles, to match wr and rd duration
          `uvm_info(get_type_name(), $sformatf(" DATA READ rd_data %0d", vif.dout), UVM_NONE)	
			 req.dout = vif.dout;						// capture the stimulus from dut via vif
            @(posedge vif.clk);							 // wait for 1 clk cycles	
		end: B2
	endtask: drive
 
 

// run_phase:- task bcz contain delay:- driver drive stimuls to DUT and monitor capture information from DUT based on DUT protocol.
//	       executes in parallel and all pre-post run phases.
 
 
  
  	virtual task run_phase (uvm_phase phase);
 
    		forever begin: B1 
        		seq_item_port.get_next_item(req);
        			drive();					// calling the drive() task
        		seq_item_port.item_done();		
 
    		end: B1
 
  	endtask: run_phase

endclass: driver
 
      
// ------------------- monitor class ---------------------
 
 
// monitor class is not parameterize class.
// component class in uvm base class hierarchy hence default constructor expect two arguments.
// monitor responsibility is to capture the information from the DUT through vif and broadcast it to SB and RM(Multiple components) hence it has
// analysis port.
 
 
// monitor:- pin/signal level to pkt/stream of transactions level conversion.
 
 
class monitor extends uvm_monitor;
 
 
	transaction trans;									// instance for transaction class
 
	virtual dut_interface vif;							// interface inside class need to declare as virtual
														// bcz class is dynamic and interface is static component.
	uvm_analysis_port #(transaction) ap;				// uvm_analysis_port, one to many kind of scenario			
														// dimond shape and parameterize with type of xtn
 
	`uvm_component_utils(monitor)						// factory registration
 
	function new(input string name = "monitor", uvm_component parent = null);// component hence two arguments
		super.new(name,parent);							// components are static in nature need to be there though out the simlation
		ap = new("ap",this);							// memory allocation for ap, here or in build_phase anything is fine
	endfunction: new
 
	
// build_phase:- responsible for building all lower level components
//		 executes in top down manner.	
 
 
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		trans = transaction::type_id::create("trans");
		if(!uvm_config_db #(virtual dut_interface)::get(this, "", "virtual_intf", vif))
		`uvm_fatal(get_type_name(), "Unable to get virtual_intf vif")	
	endfunction: build_phase	
 
 
	task collect_data();
      repeat(3) @(posedge vif.clk);						// wait 3 clk cycles, same delay as mention in drv
				trans.wr_enb = vif.wr_enb;				// capturing the info form dut through vif hence blocking assignment
				trans.addr   = vif.addr;		
				trans.din    = vif.din;
				trans.dout   = vif.dout;
 
			
				`uvm_info(get_type_name(), $sformatf(" DATA SEND TO SB wr_enb is %0d, addr is %0d, din is %0d, dout is %0d",
								     trans.wr_enb, trans.addr, trans.din, trans.dout), UVM_NONE)
				ap.write(trans);						// collecting data into ap
														// ap has write method which is non-blocking in nature
	endtask: collect_data
 
 
// run_phase:- task bcz contain delay:- driver drive stimuls to DUT and monitor capture information from DUT based on DUT protocol.
//	       executes in parallel and all pre-post run phases.
 
 
	virtual task run_phase(uvm_phase phase);
		forever begin: B1
          collect_data();
		end: B1
	endtask: run_phase
 
 
endclass: monitor
 
 
      

 

// ------------------- agent class  ----------------------
 
// agent is UVC(Universal Verification Component).
// configurable one can be active i.e will have all essential components seqr,drv,mon but if passive then will have only mon.
// agent class is one kind of container and it will contains the objects for sequencer, driver and monitor classes.
// component class in uvm base class hierarchy hence default constructor expecting two arguments.
 
 
// agent don't have the run_phase bcz run phase required for the components which are doing some physical jobs like driving
// xtns or collecting xtns, but agent is just a container for seqr, drv and mon hence a part from build and connect phase
// no other phases are required.  
 
 
class agent extends uvm_agent;
 
   	`uvm_component_utils(agent)
  	 driver 						drv;
  	 uvm_sequencer#(transaction) 	seqr;
  	 monitor 						mon;

  	function new(input string name = "agent", uvm_component parent = null);
    		super.new(name, parent);
  	endfunction: new
 
 
// build_phase:- responsible for building all lower level components
//		 executes in top down manner.	
 
  
  	virtual function void build_phase(uvm_phase phase);
    		super.build_phase(phase);
    		drv = driver::type_id::create("drv", this);
      		mon  = monitor::type_id::create("mon", this);
    		seqr = uvm_sequencer#(transaction)::type_id::create("seqr", this);
  	endfunction: build_phase
 
 
// connect_phase:- responsible for establishing connection between all created components by  port-export
//		   executes in buttom up manner.
  	virtual function void connect_phase(uvm_phase phase);
    		super.connect_phase(phase);
    		drv.seq_item_port.connect(seqr.seq_item_export);
  	endfunction: connect_phase

endclass: agent


 
      
// ------------------- scoreboard class ---------------------
 
 
// receive transactions from monitor and perform comparasion with golden data.
// implementation details i.e write method(function) of analysis port.
// component class in uvm base class hierarchy hence default constructor expect two arguments
// no need to declare vif here
 
      

class scoreboard extends uvm_scoreboard;

   uvm_analysis_imp #(transaction, scoreboard) aip;		// uvm_analysis_imp ,two arguments trans & class where implimentaion
														// variable to store data, which we'r writing into reg during wr operation 
	bit [7:0] temp_data;			
 
	
	`uvm_component_utils(scoreboard)					// factory regstration
 
	function new(input string name = "scoreboard", uvm_component parent = null);	// component in UBCH hence two arguments	
		super.new(name,parent);
		aip = new("aip",this);							// object for aip
	endfunction: new
 
				
 
 
// ap has write method which is non-blocking in nature i.e function
 
 
	virtual function void write(input transaction tr);				// implementation details
 
 
		`uvm_info(get_type_name(), $sformatf("data rcvd from Monitor ap, wr_enb is %0d, addr is %0d, din is %0d, dout is %0d",
							tr.wr_enb, tr.addr, tr.din, tr.dout), UVM_NONE)
 
		
		if(tr.wr_enb) begin: B1 									// wr_enb == 1 i.e wr_operation
			if(!tr.addr) begin: B2									// addr == 0
				temp_data = tr.din;									// update the temp_data with din
				`uvm_info(get_type_name(), $sformatf(" input data is stored %0d", tr.din) ,UVM_NONE)
 
			end: B2
 
			else begin: B3											// addr != 0
 
				`uvm_info(get_type_name(), " ----  addr != 0 ---- ", UVM_NONE)
			end: B3
 
		end: B1
 
		else  begin: B4				 								// wr_enb == 0 i.e rd_operation
 
			if(!tr.addr) begin: B5									// addr == 0		
              if(tr.dout ==  temp_data)							// data on o/p is equal to data in temp_data variable
				`uvm_info(get_type_name()," ---- TEST IS PASSED ---- ",UVM_NONE)
 
			end: B5
 
			else begin: B6							// data on o/p is not equal to data in temp_data variable
 
				`uvm_info(get_type_name()," ---- TEST IS FAILED ---- ",UVM_NONE)	
			end: B6
 
		end: B4
 
	endfunction: write
 
 
endclass: scoreboard
 
 
      
 
 
// ----------------------  register class  ----------------------
 
 
 
class reg0 extends uvm_reg;
 
	`uvm_object_utils(reg0)
 
	rand uvm_reg_field  f0;								// single field F0
 
	function new(input string name = "reg0");
		super.new(name, 8, UVM_NO_COVERAGE);			// 8 -> width(size) of reg, & no seperate coverage for it
	endfunction: new

 
	// build method for fields creation and configuration method for configuration information for register
 
	virtual function void build();
 
 
		f0 = uvm_reg_field::type_id::create("f0");	
		f0.configure(					// by name
				.parent(this), 			// current class	
				.size(8), 				// width
				.lsb_pos(0), 			// lsb postion
				.access("RW"), 			// type of an access	
				.volatile(0), 			// volatile -> 1 means field can't change between consecutive access		
        	    .reset(0), 				// reset value(power on reset value for field)
				.has_reset(1), 			// field support reset
				.is_rand(1),			// field can be randomize
				.individually_accessible(1)	// field is individually accessible
 
				); 						// 9 arguments // psl avr hii
 
 
	endfunction: build

endclass: reg0
 
 
// ----------------------- register block ---------------------
 
 
class reg_blk extends uvm_reg_block;
 
 
	`uvm_object_utils(reg_blk)
 
	
	rand reg0  reg0_h;							// instances for all registers
 
	
	function new(input string name = "reg_blk");
		super.new(name, UVM_NO_COVERAGE);		// no seperate coverage 
	endfunction: new
 
 
	virtual function build();
 
		reg0_h = reg0::type_id::create("reg0_h");
		reg0_h.build();							// calling the build method of reg0
		reg0_h.configure(this);					// configure instance of reg0, this -> parent i.e here reg_blk
 
 
		// adding address map for all registers, using create_map with 4 arguments
 
		default_map = create_map("default_map", 0, 1, UVM_LITTLE_ENDIAN);	// instance, base_address, size in byte(i.e 1*8 = 8), endian
									// UVM_LITTLE_ENDIAN -> Least-significant bytes first in consecutive addresses
		// adding register to map using add_reg method with 3 arguments
 
		default_map.add_reg(reg0_h, 'h0, "RW");		// instance of register, offset_address, access, generally here "RW"  
													// note:- base_address + offset_address = physical_address of reg0
        default_map.set_auto_predict(0);			// explicit  prediction, or comment this 	
													// default_map -> bcz this method is related to map
		lock_model();								// mandatory to lock the model
													// Lock a model and build the address map.(it will build the map
	endfunction: build
								// Once locked, no further structural changes, such as adding registers or memories, can be made.
								// It is not possible to unlock a model.
 
endclass: reg_blk
 
 
 
// ------------------- register_sequence class  -------------------
 
 
 
class register_sequence extends uvm_sequence;
 
	`uvm_object_utils(register_sequence)
 
	reg_blk  reg_blk_h;								// need to add instance of reg_block
 
	
	function new(input string name = "register_sequence");
		super.new(name);
	endfunction: new


  	virtual task body();

  		// type			field
		uvm_status_e  	status;						// to store the status of txn
		bit[7:0] 		dv_data, mv_data;			// two varaibles same size of h/w reg
    	bit[7:0]		random_inp, read_out;		// variable to generate random inputs


      repeat(5) begin: B1
		// ------ frontdoor write ------
          random_inp = $urandom;

          	reg_blk_h.reg0_h.write(status, random_inp, UVM_FRONTDOOR);
			dv_data = reg_blk_h.reg0_h.get();						// get the desired variable
 
			mv_data = reg_blk_h.reg0_h.get_mirrored_value();		// get the mirrored variable
 
			`uvm_info(get_type_name(), $sformatf(" After frontdoor write method, Desired value is %0d, Mirroed value is %0d",
						       dv_data, mv_data), UVM_NONE)
 
		

 
			reg_blk_h.reg0_h.read(status, read_out, UVM_FRONTDOOR);	

			dv_data = reg_blk_h.reg0_h.get();						// get the desired variable, backdoor
 
			mv_data = reg_blk_h.reg0_h.get_mirrored_value();		// get the mirrored variable, backdoor
 
			`uvm_info(get_type_name(), $sformatf(" After frontdoor read method, Desired value is %0d, Mirroed value is %0d, read_out is %0d",
						       dv_data, mv_data, read_out), UVM_NONE)	

        $display(" ########################## -------------------- #################### ------------------ ######################### ");

        end: B1
 
 
      

		// for register model to see the current state of h/w register(i.e mirrored) predictor is manadatory
        // here is explicit predictor we have added, hence need to set_auto_predict(0);(i.e disable implicit prediction) in the reg_blk	

 
	endtask: body	
 
endclass: register_sequence
 
 
// ----------------------  adapter class  ----------------------
 
 

class adapter extends uvm_reg_adapter;
 
 
	`uvm_object_utils(adapter)
 
	function new(input string name = "adapter");
		super.new(name);
	endfunction: new

 
 
	// reg2bus method:- convert reg txn to bus txn
	// return uvm_sequence_item
 
	virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw); // 1 argument

		transaction  itm = transaction::type_id::create("itm");				// instance of txn class and object creation
 
		itm.wr_enb = (rw.kind == UVM_WRITE) ? '1 : '0;						// updating the bus txn with reg txn
		itm.addr   = rw.addr;
 
		if(itm.wr_enb)  itm.din  = rw.data;

		return itm;
	endfunction: reg2bus
 
 
	// bus2reg:- convert bus txn to reg txn
 
 
	virtual function void bus2reg(uvm_sequence_item  bus_item, ref uvm_reg_bus_op rw); // 2 arguments
		transaction itm;						// instance of xtn class
		assert($cast(itm, bus_item));					// to get correct child class
 
		rw.kind = (itm.wr_enb) ? UVM_WRITE : UVM_READ;			// updating the reg txn with bus txn
		rw.data = (itm.wr_enb) ? itm.din : itm.dout;
		rw.addr = itm.addr;
		rw.status = UVM_IS_OK;
	endfunction: bus2reg
 
 
endclass: adapter
 
 
 
// ----------------------  env class  ----------------------
 
// instances of sb, agent and coverage collector if any
// connect analysis port(ap) of monitor and analysis implimentation(aip) port of SB
// monitor is an initiator and SB is a target.
 
 
// but here just creating an agent, regmodel, adapter
 
 
 
class env extends uvm_env;
 
 
	agent 	 		agt_h;						// instance of an agent 
	reg_blk 	 	reg_blk_h;					// instance of reg_blk
	adapter	 		adapter_h;					// instance of an adapter

	uvm_reg_predictor	#(transaction) predictor_h;			// instance of predictor(in build predictor)
	scoreboard		    sb_h;

 
 
  	`uvm_component_utils(env)

  	function new(input string name = "env", uvm_component parent = null);
    		super.new(name, parent);
  	endfunction: new
 
 
// build_phase:- responsible for building all lower level components
//		 executes in top down manner.	
 
  
  	virtual function void build_phase(uvm_phase phase);
    		super.build_phase(phase);
      		predictor_h = uvm_reg_predictor #(transaction)::type_id::create("predictor_h", this);
    		agt_h = agent::type_id::create("agt_h", this);
      		sb_h = scoreboard::type_id::create("sb_h", this);
			reg_blk_h = reg_blk::type_id::create("reg_blk_h", this);
			reg_blk_h.build();						// calling the build method of reg_blk
			adapter_h = adapter::type_id::create("adapter_h",, get_full_name());
  	endfunction: build_phase
 
 
// connect_phase:- responsible for establishing connection between all created components by  port-export
//		   executes in buttom up manner.
 
 
// here we have to speciry sequencer on which we want to start reg_sequence
 
 
	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
 
		agt_h.mon.ap.connect(sb_h.aip);							// connection of mon(ap) and sb(aip)
 
		reg_blk_h.default_map.set_sequencer(.sequencer(agt_h.seqr), .adapter(adapter_h)); // .set_sequencer method with 2 arguments
		reg_blk_h.default_map.set_base_addr(0);						  // .set_base_addr method, base addr for map
											 					 // at any point need to change base addr we can use this method		
		predictor_h.map = reg_blk_h.default_map;				// predictor map with default_map which is reg_blk_h
		predictor_h.adapter = adapter_h;						// accessing map and adapter handles
 
		agt_h.mon.ap.connect(predictor_h.bus_in);								
																	// connection of mon(ap) and predictor	
	endfunction: connect_phase		

endclass: env
 
 
 
 
// ------------------- base_test class ----------------------
 
 
// creating an env and setting a configuration parameter
 
 
class base_test extends uvm_test;
	env 		env_h;									// instances/handler for env
 
	`uvm_component_utils(base_test)						// factory registration
 
	function new(input string name = "base_test", uvm_component parent = null);	// component hence two arguments	
		super.new(name,parent);
	endfunction: new
 
			
 
// build_phase:- responsible for building all lower level components
//		 executes in top down manner.	
 
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		env_h = env::type_id::create("env",this);				// creating an objects for env and generator(sequence)
	endfunction: build_phase
 
 
// end_of_elaboration_phase:- print_topology executes in buttom up manner.
//	       			
 
	virtual function void end_of_elaboration_phase(uvm_phase phase);
		super.end_of_elaboration_phase(phase);
		uvm_top.print_topology();	
	endfunction: end_of_elaboration_phase
 
 
// report_phase:- display result of the simulation.
//		  executes in buttom up manner.
 
 
	virtual function void report_phase(uvm_phase phase);
		uvm_report_server svr;
 
		super.report_phase(phase);
 
		svr = uvm_report_server::get_server();
 
		if(svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) > 0) begin: B1
 
			`uvm_info(get_type_name(), "--------------------------------------", UVM_NONE)
			`uvm_info(get_type_name(), "-------------- TEST FAIL -------------", UVM_NONE)
			`uvm_info(get_type_name(), "--------------------------------------", UVM_NONE)
 
		end: B1
		else begin: B2
 
			`uvm_info(get_type_name(), "--------------------------------------", UVM_NONE)
			`uvm_info(get_type_name(), "-------------- TEST PASS -------------", UVM_NONE)
			`uvm_info(get_type_name(), "--------------------------------------", UVM_NONE)
 
		end: B2
 
	endfunction: report_phase
 
 
endclass: base_test
 
 
 

/////////////////////////////  test  ////////////////////////////////////
 
 

class test extends base_test;
 
 
  	`uvm_component_utils(test)					// component FR macrow
	register_sequence reg_seq;					// instance of register_sequence

  	function new(input string name = "test", uvm_component parent = null);
    		super.new(name, parent);
  	endfunction: new
 
 
// build_phase:- responsible for building all lower level components
//		 executes in top down manner.	
 
 
	virtual function void build_phase(uvm_phase phase);		// simply calling super.build_phase bcz parent 
		super.build_phase(phase);				// build_phase containing a logic corresponding,to config_db and creating the env
 
		reg_seq = register_sequence::type_id::create("reg_seq");
 
	endfunction: build_phase					
 
 
// run_phase:- task bcz contain delay:- driver drive stimuls to DUT and monitor capture information from DUT based on DUT protocol.
//	       executes in parallel and all pre-post run phases.
 

  	virtual task run_phase(uvm_phase phase);
 
    		phase.raise_objection(this);
				reg_seq.reg_blk_h = env_h.reg_blk_h;
    			reg_seq.start(env_h.agt_h.seqr);
    		phase.drop_objection(this);
 
			phase.phase_done.set_drain_time(this, 300);		// set_drain_time so that all the stimulus process sucessfully
 
  	endtask: run_phase
 
endclass: test

 
 

// ------------------- top module ----------------------
 
 
module top_tb();
 
 
	dut_interface vif();							// () is mandatory
 
	register_dut DUT(
 
			.clk(vif.clk),							// DUT instantiation
			.rst(vif.rst),
			.addr(vif.addr),
			.wr_enb(vif.wr_enb),
			.din(vif.din),					
			.dout(vif.dout)
 
			);
 
												// design(DUT) instantiation	
	initial begin: B1						
		vif.clk = '0;						
      uvm_config_db #(virtual dut_interface)::set(null, "*", "virtual_intf", vif);
		run_test("test");						// run_test is a method(taks) to run specific test with paranethesis we can pass the argument which test name
	end: B1	

	always #10 vif.clk = ~ vif.clk;					// generating clk of time period is 20ns

	initial begin: B2
 
		$dumpfile("dump.vcd");
    	$dumpvars;
 
	end: B2
 
 
endmodule: top_tb
// interface 

 
 
interface dut_interface();
 
	parameter size = 8;
	logic clk,rst;	  		 // active high rst
	logic [size - 1 :0] din;  
	logic wr_enb;		  	 // mode controll bit wr_enb = 1 then write in to ram else read 
	logic addr;		   	
	logic [size - 1 :0] dout;		   

endinterface: dut_interface
 
