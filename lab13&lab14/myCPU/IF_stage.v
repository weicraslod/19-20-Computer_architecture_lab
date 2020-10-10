`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,            //ds_allowin����������������ID
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,            //��IF��������ID��Ч
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,            //IF��ID����
    // inst sram interface
    output      inst_req   ,
    output [ 3:0] inst_sram_wen  ,
    output [31:0] inst_sram_addr ,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata,
    input  [36   :0]                ws_to_fs_bus,
    
    input  inst_data_ok,
    input  inst_addr_ok,
    
    // search port 0
            output  [              18:0] s0_vpn2,
            output                       s0_odd_page,     
           // input  [               7:0] s0_asid,     
            input                      s0_found,     
            input [               3:0] s0_index,     
            input [              19:0] s0_pfn,     
            input [               2:0] s0_c,     
            input                      s0_d,     
            input                      s0_v
);
/////////////////////////////////////ȡֵ��û��д���⴦��
reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;
wire        mapped;
wire inst_sram_en;

wire [31:0] seq_pc;
wire [31:0] nextpc;

wire         br_taken;                                          //��ID�д�������pc�Ƿ���ת
wire [ 31:0] br_target;
wire         fs_bd;
wire         fs_refetch;
reg FS_BD;
wire [31:0] true_npc;
always@(posedge clk)begin
    if(reset)
        FS_BD <= 1'b0;
    else if(fs_bd)
        FS_BD <= 1'b1;
    else if(fs_to_ds_valid)
        FS_BD <= 1'b0;
        end
reg FS_REFETCH;
always@(posedge clk)begin
    if(reset)
        FS_REFETCH <= 1'b0;
    else if(fs_refetch)
        FS_REFETCH <= 1'b1;
    else if(fs_to_ds_valid)
        FS_REFETCH <= 1'b0;
        end
wire j_reg;
assign {fs_refetch,j_reg,fs_bd,br_taken,br_target} = br_bus;

wire [31:0] fs_inst;                                            //ȡֵ�Ĵ���
reg  [31:0] fs_pc;                                              //pc������
wire [31:0] badvaddr;
wire fs_ex;
wire tlb_miss;
wire tlb_invalid;
wire tlb_ex;
reg tlb_miss_reg;
reg tlb_invalid_reg;
assign fs_to_ds_bus = {
                       tlb_invalid_reg,//100
                       tlb_miss_reg,//99
                       FS_REFETCH,//98
                       fs_ex,   //97
                       badvaddr,//96:65
                      // fs_bd,   //64
                       FS_BD,   //64
                       fs_inst ,//63:32
                       fs_pc   };   
wire ft_address_error;
wire wb_ex;
reg [31:0] BAD_VADDR;
assign tlb_miss=!s0_found&&mapped;
assign tlb_invalid=s0_found&&!s0_v&&mapped;

always @(posedge clk)begin
    /*if(reset)
        tlb_miss_reg<=0;
    else if(tlb_miss && to_fs_valid && fs_allowin)
        tlb_miss_reg<=1;
    else if(tlb_miss_reg&&fs_to_ds_valid && ds_allowin)
        tlb_miss_reg<=0;
    
    if(reset)
        tlb_invalid_reg<=0;
    else if(tlb_invalid && to_fs_valid && fs_allowin)
        tlb_invalid_reg<=1;
    else if(tlb_invalid_reg&&fs_to_ds_valid && ds_allowin)
        tlb_invalid_reg<=0;*/
    
    if(reset)
        tlb_miss_reg<=0;
    else if(to_fs_valid && fs_allowin)
        tlb_miss_reg<=tlb_miss;
    
    if(reset)
        tlb_invalid_reg<=0;
    else if( to_fs_valid && fs_allowin)
        tlb_invalid_reg<=tlb_invalid;
        
    if(reset)
         BAD_VADDR<=0;
    else if(to_fs_valid && fs_allowin)
         BAD_VADDR<=true_npc;
       
    /*if(reset)
        BAD_VADDR<=0;
    else
        BAD_VADDR<=true_npc;
     
     //////////  
    if(reset)
        tlb_miss<=0;
    else if(!s0_found&&mapped)
        tlb_miss<=1;
    else if(fs_to_ds_valid&&ds_allowin)
        tlb_miss<=0; 
        
    if(reset)
        tlb_invalid<=0;
    else if(s0_found&&!s0_v&&mapped)
        tlb_invalid<=1;
    else if(fs_to_ds_valid&&ds_allowin)
        tlb_invalid<=0;  */
end
//assign ft_address_error = ~(nextpc[1:0] == 2'b00); //����bug
assign ft_address_error = ~(fs_pc[1:0] == 2'b00); 


assign fs_ex = (ft_address_error|tlb_miss_reg|tlb_invalid_reg) && fs_valid && ~wb_ex; //��wb_ex�ź�Ϊ�������ˮ��
assign badvaddr = (ft_address_error)? fs_pc:
                   (tlb_miss_reg|tlb_invalid_reg)?BAD_VADDR
                   : 32'h0;
////////////////////////////////////

wire inst_eret;
wire [31:0] cp0_rdata;
wire ws_refetch;
assign {
        tlb_ex,
        ws_refetch,
        wb_ex,
        inst_eret,
        cp0_rdata
} = ws_to_fs_bus;  
/////////////////////////////////

reg br_valid;
reg [31:0] buf_br;
reg [31:0] buf_npc;
reg  [1:0]buf_valid;
reg WB_EX;
reg J_REG;
reg TLB_EX;
always@(posedge clk)begin
    if(reset)
        TLB_EX<=1'b0;
    else if(tlb_ex)
        TLB_EX<=1'b1;
    else if(inst_addr_ok)
        TLB_EX<=1'b0;
        end
always@(posedge clk)begin
    if(reset)
        WB_EX<=1'b0;
    else if(wb_ex)
        WB_EX<=1'b1;
    else if(inst_addr_ok)
        WB_EX<=1'b0;
        end
reg INST_ERET;
always@(posedge clk)begin
    if(reset)
        INST_ERET<=1'b0;
    else if(inst_eret)
        INST_ERET<=1'b1;
    else if(inst_addr_ok)
        INST_ERET<=1'b0;
        end
reg WS_REFETCH;
always@(posedge clk)begin
    if(reset)
        WS_REFETCH<=1'b0;
    else if(ws_refetch)
        WS_REFETCH<=1'b1;
    else if(inst_addr_ok)
        WS_REFETCH<=1'b0;
        end
//assign true_npc=wb_ex? 32'hbfc00380 :
assign true_npc= (WB_EX&&TLB_EX)?32'hbfc00200:
                 (WB_EX&&~TLB_EX)?32'hbfc00380:
               // inst_eret? cp0_rdata :
                INST_ERET? cp0_rdata :
                WS_REFETCH?cp0_rdata:
                buf_valid ?buf_npc:
                br_valid & (j_reg | ~br_taken)?buf_br:     //j_regΪ0ʱ����ǰ�����
                nextpc;
//tlb search
wire [31:0]TRUE_NPC;
assign s0_vpn2 = true_npc[31:13];
assign s0_odd_page = true_npc[12];
assign TRUE_NPC = (true_npc[31:28] < 4'h8 || true_npc[31:28] >= 4'hc)? {s0_pfn,{true_npc[11:0]}}
                 :true_npc;//mapped and unmapped
assign mapped= (true_npc[31:28] < 4'h8 || true_npc[31:28] >= 4'hc);            
/////////////                 
always @(posedge clk)begin
    if(reset)
        buf_valid<=2'b00;
    else if(to_fs_valid&& fs_allowin)
        buf_valid<=1'b0;
    else if(!buf_valid&&!br_valid)
        buf_valid<=1'b1;
        
    if(!buf_valid)
        buf_npc<=nextpc;
end

always @(posedge clk)begin
    if(reset) begin
        br_valid<=0;
        J_REG <= 1;
        end
      else if(br_taken)
                br_valid<=1;
       else if(to_fs_valid&& fs_allowin)
                br_valid<=0;         
      //lab11 -> lab13�ĸĶ���ע�⣡
   /* else if(to_fs_valid&& fs_allowin)
        br_valid<=0;
    else if(br_taken)
        br_valid<=1;*/
        /////////
    else if(WB_EX | INST_ERET | WS_REFETCH)
        br_valid<=0;
    ///////////
    if(br_taken)
        buf_br<=br_target;
        
    if(j_reg)
        J_REG <= 0;
    else if(to_fs_valid&& fs_allowin)
        J_REG <= 1;
end

//////////////////////////////////
// pre-IF stage
//assign inst_req     =~reset && fs_allowin;
assign inst_req     =~reset && fs_allowin;
assign to_fs_valid  = ~reset && (inst_addr_ok);
//assign to_fs_valid  = ~reset && inst_addr_ok;                                    //pc��д��
assign seq_pc       = fs_pc + 3'h4;                             //pc+4

assign nextpc       =  (wb_ex&&!tlb_ex)? 32'hbfc00380 :
                        (wb_ex&&tlb_ex)?32'hbfc00200:
                        inst_eret | ws_refetch ? cp0_rdata :
                        br_taken ? br_target : seq_pc; 
///////////////////////////////////                        
// IF stage
reg inst_data_arrived;
always @(posedge clk) begin
    if(reset)
        inst_data_arrived<=0;
    else if(fs_to_ds_valid && ds_allowin)
        inst_data_arrived<=0;
    else if(inst_data_ok)
        inst_data_arrived<=1;
end
       
//assign fs_ready_go    = inst_data_ok||inst_data_arrived;
//assign fs_ready_go    = inst_data_arrived;
assign fs_ready_go    = inst_data_arrived;
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin; //fs���Է�����ds�������룬����һ��fs�����ݾͽ�����  ��  fs��������Ч
assign fs_to_ds_valid =  fs_valid && fs_ready_go;               //fs��������Ч��fs���Է���
always @(posedge clk) begin
    if (reset) begin                                           //
        fs_valid <= 1'b0;                                     //reset�ڼ�fs_valid��ֵΪ0
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;                              //���fs��������
    end

    if (reset) begin
        fs_pc <= 32'hbfbffffc;  //trick: to make nextpc be 0xbfc00000 during reset 
    end
    else if(wb_ex&&!tlb_ex)
        fs_pc <= 32'hbfc00380;
     else if(wb_ex&&tlb_ex)
        fs_pc <= 32'hbfc00200;
    else if(inst_eret | ws_refetch)
        fs_pc <= cp0_rdata;
    else if (to_fs_valid && fs_allowin) begin                   //����ʱ��pcΪ32'hbfbffffc��uuΪbfc00000����ʱ�����ram����һ�Ĺ���pc������bfc00000����ʱinst_sram_rdataΪbfc00000��Ӧ��ָ��
        //fs_pc <= true_npc;
        //if(tlb_miss_reg||tlb_invalid_reg)
        if(tlb_miss||tlb_invalid)
            fs_pc<=true_npc;
        else
            fs_pc <= TRUE_NPC;
    end
end

assign inst_sram_en    = to_fs_valid && fs_allowin;
assign inst_sram_wen   = 4'h0;
//assign inst_sram_addr  = true_npc;
assign inst_sram_addr  = (tlb_miss||tlb_invalid)?32'hbfc00380:TRUE_NPC;
assign inst_sram_wdata = 32'b0;


//assign fs_inst         =  (~WB_EX & ~fs_ex & ~inst_eret )? inst_sram_rdata : 32'b0;   //������Ϊbug
assign fs_inst         =  (~WB_EX & ~fs_ex & ~inst_eret & ~ws_refetch &~tlb_miss_reg &~tlb_invalid_reg)? inst_sram_rdata : 32'b0;
/////���������eret�Ĵ��������޸�fs_pc��ֵ�����ǽ�fs_instָ���Ϊ0���Ϳ����������Ч��




endmodule