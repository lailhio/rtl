`include "defines2.vh"

module tlb (
    input wire clk, rst,

    input wire [31:0] inst_vaddr,
    input wire [31:0] data_vaddr,
    input wire inst_en,
    input wire mem_readE, mem_writeE,

    output wire [`TAG_WIDTH-1:0] inst_pfn,
    output wire [`TAG_WIDTH-1:0] data_pfn,
    output wire no_cache_i,
    output wire no_cache_d,
    
    //异常
    output wire inst_tlb_refill, inst_tlb_invalid,
    output wire data_tlb_refill, data_tlb_invalid, data_tlb_modify,

    //TLB指令
	input  wire        TLBP,
	input  wire        TLBR,
    input  wire        TLBWI,
    input  wire        TLBWR,
    
    input  wire [31:0] EntryHi_in,
	input  wire [31:0] PageMask_in,
	input  wire [31:0] EntryLo0_in,
	input  wire [31:0] EntryLo1_in,
	input  wire [31:0] Index_in,
    input  wire [31:0] Random_in,

	output wire [31:0] EntryHi_out,
	output wire [31:0] PageMask_out,
	output wire [31:0] EntryLo0_out,
	output wire [31:0] EntryLo1_out,
	output wire [31:0] Index_out
);
/**
    查找TLB逻辑:
        将输入的地址与TLB中的每一项做对比，生成一个mask(只有1位为1)，然后通过编码器生成一个索引index。
        1. 如果是访存指令，由于输入的地址是E阶段的，因此将index经过一级流水线(为M阶段)，得到index_r。
            通过index_r访问TLB中的特定项，获得tlb_entrylo，从而获得其中的pfn, flag等信息
        2. 如果是TLBP指令，则index是根据M阶段的EntryHi_in产生的，直接将其赋值给EntryHi_out
    读TLB逻辑：
        根据index直接访问TLB中对应的项，index可以来自地址查找生成的index，也可以来自TLBR的Index_in
    写TLB逻辑：
        TLBWI, TLBWR
*/

//TLB
reg [31:0] TLB_EntryHi  [`TLB_LINE_NUM-1:0]; //G位放在EntryHi的第12位
reg [31:0] TLB_PageMask [`TLB_LINE_NUM-1:0];
reg [31:0] TLB_EntryLo0 [`TLB_LINE_NUM-1:0];
reg [31:0] TLB_EntryLo1 [`TLB_LINE_NUM-1:0];

//--------------------------查找逻辑-----------------------------
wire [31:0] vaddr1, vaddr2, vaddr3;

assign vaddr1 = inst_vaddr;
assign vaddr2 = data_vaddr;
assign vaddr3 = EntryHi_in;

wire  [`TLB_LINE_NUM-1: 0]     find_mask1, find_mask2, find_mask3;
wire  [`LOG2_TLB_LINE_NUM-1:0] find_index1, find_index2, find_index3;
wire find1, find2, find3;
assign find1 = |find_mask1;
assign find2 = |find_mask2;
assign find3 = |find_mask3;

genvar i;
generate
	for (i = 0; i < `TLB_LINE_NUM; i = i + 1)
	begin : find
		assign find_mask1[i] = ((vaddr1[`VPN2_BITS] & ~TLB_PageMask[i][`VPN2_BITS]) == (TLB_EntryHi[i][`VPN2_BITS] & ~TLB_PageMask[i][`VPN2_BITS])) && (TLB_EntryHi[i][`G_BIT] || TLB_EntryHi[i][`ASID_BITS] == EntryHi_in[`ASID_BITS]); 
		assign find_mask2[i] = ((vaddr2[`VPN2_BITS] & ~TLB_PageMask[i][`VPN2_BITS]) == (TLB_EntryHi[i][`VPN2_BITS] & ~TLB_PageMask[i][`VPN2_BITS])) && (TLB_EntryHi[i][`G_BIT] || TLB_EntryHi[i][`ASID_BITS] == EntryHi_in[`ASID_BITS]);		
		assign find_mask3[i] = ((vaddr3[`VPN2_BITS] & ~TLB_PageMask[i][`VPN2_BITS]) == (TLB_EntryHi[i][`VPN2_BITS] & ~TLB_PageMask[i][`VPN2_BITS])) && (TLB_EntryHi[i][`G_BIT] || TLB_EntryHi[i][`ASID_BITS] == EntryHi_in[`ASID_BITS]);		
	end
endgenerate

//编码器，通过mask生成index
assign find_index2=
({5{find_mask2[0 ]}} & 5'd0 ) |
({5{find_mask2[1 ]}} & 5'd1 ) |
({5{find_mask2[2 ]}} & 5'd2 ) |
({5{find_mask2[3 ]}} & 5'd3 ) |
({5{find_mask2[4 ]}} & 5'd4 ) |
({5{find_mask2[5 ]}} & 5'd5 ) |
({5{find_mask2[6 ]}} & 5'd6 ) |
({5{find_mask2[7 ]}} & 5'd7 ) ;


assign find_index1=
({5{find_mask1[0 ]}} & 5'd0 ) |
({5{find_mask1[1 ]}} & 5'd1 ) |
({5{find_mask1[2 ]}} & 5'd2 ) |
({5{find_mask1[3 ]}} & 5'd3 ) |
({5{find_mask1[4 ]}} & 5'd4 ) |
({5{find_mask1[5 ]}} & 5'd5 ) |
({5{find_mask1[6 ]}} & 5'd6 ) |
({5{find_mask1[7 ]}} & 5'd7 ) ;

assign find_index3 = 
({5{find_mask3[0 ]}} & 5'd0 ) |
({5{find_mask3[1 ]}} & 5'd1 ) |
({5{find_mask3[2 ]}} & 5'd2 ) |
({5{find_mask3[3 ]}} & 5'd3 ) |
({5{find_mask3[4 ]}} & 5'd4 ) |
({5{find_mask3[5 ]}} & 5'd5 ) |
({5{find_mask3[6 ]}} & 5'd6 ) |
({5{find_mask3[7 ]}} & 5'd7 ) ;
//--------------------------查找逻辑-----------------------------

//--------------------------读TLB逻辑-----------------------------
wire [`LOG2_TLB_LINE_NUM-1: 0] index1, index2, index3;
assign index1 = find_index1;
assign index2 = find_index2;
assign index3 = TLBP ? find_index3 : Index_in[`INDEX_BITS];

wire [31:0] EntryLo0_read1;
wire [31:0] EntryLo1_read1;

wire [31:0] EntryLo0_read2;
wire [31:0] EntryLo1_read2;

wire [31:0] EntryHi_read3;
wire [31:0] PageMask_read3;
wire [31:0] EntryLo0_read3;
wire [31:0] EntryLo1_read3;

reg [31:0] EntryLo0_read2_r;
reg [31:0] EntryLo1_read2_r;

assign EntryLo0_read1 =TLB_EntryLo0[index1];
assign EntryLo1_read1 =TLB_EntryLo1[index1];

assign EntryLo0_read2 =TLB_EntryLo0[index2];
assign EntryLo1_read2 =TLB_EntryLo1[index2];

assign EntryHi_read3  =TLB_EntryHi[index3];
assign PageMask_read3 =TLB_PageMask[index3];
assign EntryLo0_read3 =TLB_EntryLo0[index3];
assign EntryLo1_read3 =TLB_EntryLo1[index3];


//--------------------------读TLB逻辑-----------------------------

//--------------------------写TLB逻辑-----------------------------
wire [`LOG2_TLB_LINE_NUM-1: 0] write_index;
assign write_index = TLBWI ? Index_in[`INDEX_BITS] : Random_in[`INDEX_BITS];

integer tt;
always @(posedge clk)
begin
    if(rst) begin
        for(tt=0; tt<`TLB_LINE_NUM; tt=tt+1) begin
            TLB_EntryHi [tt] <= 0;
            TLB_PageMask[tt] <= 0;
            TLB_EntryLo0[tt] <= 0;
            TLB_EntryLo1[tt] <= 0;
        end
    end
    else if (TLBWI | TLBWR)
    begin
        TLB_EntryHi [write_index][`VPN2_BITS] <= EntryHi_in[`VPN2_BITS];
        TLB_EntryHi [write_index][`G_BIT]     <= EntryLo0_in[0] & EntryLo1_in[0];
        TLB_EntryHi [write_index][`ASID_BITS] <= EntryHi_in[`ASID_BITS];
        TLB_PageMask[write_index]             <= PageMask_in;
        TLB_EntryLo0[write_index][`PFN_BITS]  <= EntryLo0_in[`PFN_BITS];
        TLB_EntryLo0[write_index][`C_BITS]    <= EntryLo0_in[`C_BITS];
        TLB_EntryLo0[write_index][`D_BIT]     <= EntryLo0_in[`D_BIT];
        TLB_EntryLo0[write_index][`V_BIT]     <= EntryLo0_in[`V_BIT];
        TLB_EntryLo1[write_index][`PFN_BITS]  <= EntryLo1_in[`PFN_BITS];
        TLB_EntryLo1[write_index][`C_BITS]    <= EntryLo1_in[`C_BITS];
        TLB_EntryLo1[write_index][`D_BIT]     <= EntryLo1_in[`D_BIT];
        TLB_EntryLo1[write_index][`V_BIT]     <= EntryLo1_in[`V_BIT];
    end
end
//--------------------------写TLB逻辑-----------------------------

//--------------------------output---------------------------------
/*data地址映射*/
wire data_oddE; 

assign data_oddE = data_vaddr[`OFFSET_WIDTH];

wire data_kseg01E;

wire data_kseg1E;

assign data_kseg01E = data_vaddr[31:30]==2'b10 ? 1'b1 : 1'b0;
assign data_kseg1E = data_vaddr[31:29]==3'b101 
                    || (data_vaddr[31] & ~(|data_vaddr[30:22]) & (|data_vaddr[21:20])) //8010_0000 - 803F_FFFF 为跑监控程序时用户代码空间。直接设置为非cache，从而不用实现i_cache和d_cache的一致性
                    ? 1'b1 : 1'b0;

wire [`TAG_WIDTH-1:0] data_vpnE;

assign data_vpnE = data_vaddr[31:`OFFSET_WIDTH];

//M阶段的data的物理页号
assign data_pfn = data_kseg01E? {3'b0, data_vpnE[`TAG_WIDTH-4:0]} :
                 ~data_oddE   ? EntryLo0_read2[`PFN_BITS] : EntryLo1_read2[`PFN_BITS];

wire [5:0] data_flag;
assign data_flag = ~data_oddE ? EntryLo0_read2[`FLAG_BITS] : EntryLo1_read2[`FLAG_BITS];

assign no_cache_d = data_kseg01E ? (data_kseg1E ? 1'b1 : 1'b0) :
                    data_flag[`C_BITS]==3'b010 ? 1'b1 : 1'b0;
// assign no_cache_d = data_kseg1E ? 1'b1 : 1'b0;
/*inst地址映射*/
wire inst_oddE;

assign inst_oddE = inst_vaddr[`OFFSET_WIDTH];

wire inst_kseg01E, inst_kseg1E;

assign inst_kseg01E = inst_vaddr[31:30]==2'b10 ? 1'b1 : 1'b0;
assign inst_kseg1E = inst_vaddr[31:29]==3'b101 ? 1'b1 : 1'b0;

wire [`TAG_WIDTH-1:0] inst_vpnE;

assign inst_vpnE = inst_vaddr[31:`OFFSET_WIDTH];

assign inst_pfn = inst_kseg01E? {3'b0, inst_vpnE[`TAG_WIDTH-4:0]} :
                 ~inst_oddE  ? EntryLo0_read1[`PFN_BITS] : EntryLo1_read1[`PFN_BITS];

wire [5:0] inst_flag;
assign inst_flag = ~inst_oddE ? EntryLo0_read1[`FLAG_BITS] : EntryLo1_read1[`FLAG_BITS];

assign no_cache_i = inst_kseg01E ? (inst_kseg1E ? 1'b1 : 1'b0) :
                    inst_flag[`C_BITS]==3'b010 ? 1'b1 : 1'b0;

/*TLB指令*/
    //TLBR
assign EntryHi_out  = EntryHi_read3;
assign PageMask_out = PageMask_read3;
assign EntryLo0_out = {EntryLo0_read3[31:1], EntryHi_read3[`G_BIT]};
assign EntryLo1_out = {EntryLo1_read3[31:1], EntryHi_read3[`G_BIT]};

    //TLBP
assign Index_out    = find3 ? find_index3 : 32'h8000_0000;

//异常
    //取指TLB异常
assign inst_tlb_refill  = inst_kseg01E ? 1'b0 : (inst_en & ~find1);
assign inst_tlb_invalid = inst_kseg01E ? 1'b0 : (inst_en & find1 & ~inst_flag[`V_BIT]);

    //load/store TLB异常
wire data_V, data_D;
assign data_V = data_flag[`V_BIT];
assign data_D = data_flag[`D_BIT];

assign data_tlb_refill  = data_kseg01E ? 1'b0 : (mem_readE | mem_writeE) & ~find2;
assign data_tlb_invalid = data_kseg01E ? 1'b0 : (mem_readE | mem_writeE) & find2 & ~data_V;
assign data_tlb_modify  = data_kseg01E ? 1'b0 : mem_writeE & find2 & data_V & ~data_D;
//--------------------------output---------------------------------


endmodule