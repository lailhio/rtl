module hazard(
    input wire i_cache_stall,
	input wire d_cache_stall,
    input wire alu_stallE, 

    input wire flush_pred_failedE, flush_exceptionE, jumpD,
    input wire branchD, branchE, pre_right, pred_takeD,

    input wire is_mfcE, // cp0 read sign
    input wire hilotoregE, //hilo read sign
    input wire [4:0] rsD,  // operand
    input wire [4:0] rtD, 
    input wire regwriteE,
    input wire regwriteM,
    // input wire regwriteM2,
    input wire regwriteW,  // whether to write reg
    input wire [4:0] writeregE, // write which reg
    input wire [4:0] writeregM,
    // input wire [4:0] writeregM2,
    input wire [4:0] writeregW,

    input wire mem_readE,   //Ex's Memread sign, lw lb lhb 
    // input wire mem_readM, 
    
    input wire  Blank_SL,
    output wire stallF, stallF2, stallD, stallE, stallM, stallW,
    output wire flushF, flushF2, flushD, flushE, flushM, flushW,
    output wire longest_stall, stallDblank, icache_Ctl, dcache_ctl,flush_pc_debugM,

    output wire [1:0] forward_1D, forward_2D //000-> NONE, 001-> WRITE, 010-> M2, 011 -> M , 100 -> E
);
    
    wire id_cache_stall;
    //  1、 if Ex、Mem or Wb is same
    //  2、 And if ExInst is lw or Mfhilo
    //  ps : lw des rt, mfc0 des rt, mfhilo des rd
    assign forward_1D = ((rsD != 0)) & regwriteE & ((rsD == writeregE)) ? 2'b11 :
                        ((rsD != 0)) & regwriteM & ((rsD == writeregM)) ? 2'b10 :
                        ((rsD != 0)) & regwriteW & ((rsD == writeregW)) ? 2'b01 :
                        2'b00;
    assign forward_2D = ((rtD != 0)) & regwriteE & ((rtD == writeregE)) ? 2'b11 :
                        ((rtD != 0)) & regwriteM & ((rtD == writeregM)) ? 2'b10 :
                        ((rtD != 0)) & regwriteW & ((rtD == writeregW)) ? 2'b01 :
                        2'b00;
    assign id_cache_stall=d_cache_stall|i_cache_stall;

    wire branch_ok =  pred_takeD ;
    assign flush_pc_debugM = ~stallM & Blank_SL;
    
    assign longest_stall=id_cache_stall|alu_stallE;
    // Is mfc0 mfhilo lw and Operand is the same 
    assign stallDblank= regwriteE & mem_readE & (((rsD != 0) & (rsD == writeregE)) | ((rtD != 0) & (rtD == writeregE)));
    assign stallF = ~flush_exceptionE & (id_cache_stall | alu_stallE | stallDblank | Blank_SL);
    assign icache_Ctl = d_cache_stall | alu_stallE| stallDblank | Blank_SL;
    assign dcache_ctl = (i_cache_stall | alu_stallE);
    assign stallF2 =  id_cache_stall | alu_stallE| stallDblank | Blank_SL;
    assign stallD =  id_cache_stall| alu_stallE | stallDblank | Blank_SL;
    assign stallE =  id_cache_stall| alu_stallE | Blank_SL;
    // assign stallM =  id_cache_stall| alu_stallE | Blank_SL;
    assign stallM = (id_cache_stall| alu_stallE);
    assign stallW =  ~flush_exceptionE &(id_cache_stall | alu_stallE);

    assign flushF = 1'b0;
    assign flushF2 = flush_exceptionE | flush_pred_failedE | ((jumpD | branch_ok) & ~stallF2); 
    assign flushD = flush_exceptionE | (flush_pred_failedE & ~stallD); 
    assign flushE = flush_exceptionE | (stallDblank & ~stallE ) ; 
    // assign flushM = flush_exceptionM;
    assign flushM = flush_exceptionE |(~stallM & Blank_SL);
    assign flushW = 1'b0;
endmodule