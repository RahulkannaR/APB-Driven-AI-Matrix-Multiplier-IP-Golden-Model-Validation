`include "headers.vh"
import matmul_pkg::*;

// Stimulus Module - Minimal fixed version
module matmul_stimulus #(
    parameter string MAT_A_FILE = "",
    parameter string MAT_B_FILE = ""
)(
    matmul_interface.matmul_stimulus intf
);

`define NULL 0

// Default file paths (can override via parameters)
parameter string MAT_A = "matrixa.txt";
parameter string MAT_B = "matrixb.txt";
parameter string MAT_C = "matrixc.txt";
parameter string PARAMETERS = "parameters.txt";
parameter string DIMENSIONS = "dimensions.txt";

import matmul_pkg::*;

// indexes and buffers
reg [5:0] i, j;
reg [BUS_WIDTH-1:0] mat_a;
reg [BUS_WIDTH-1:0] mat_b;
reg [1:0] line_number;

integer mat_a_fd, mat_b_fd, mat_c_fd, parameters_fd, dimensions_fd;
integer read_line_fd, assign_line_fd;

logic unsigned [2:0] n_dim, k_dim, m_dim;
integer DW, BW, AW, SPN, count_error, count_right, incorrect_flag;
string line;
integer k, p;

int total_errors = 0;
int total_correct = 0;
int count = 0; // number of matrices processed
bit cont = 1;

// matrices and line-packed versions
logic signed [DATA_WIDTH-1:0] matA [0:MAX_DIM-1][0:MAX_DIM-1];
logic signed [BUS_WIDTH-1:0] matA_lines [0:MAX_DIM-1];
logic signed [BUS_WIDTH-1:0] matB_lines [0:MAX_DIM-1];
logic signed [DATA_WIDTH-1:0] matB [0:MAX_DIM-1][0:MAX_DIM-1];
logic signed [BUS_WIDTH-1:0] matC [0:MAX_DIM-1][0:MAX_DIM-1];
logic signed [BUS_WIDTH-1:0] matC_from_sp [0:MAX_DIM*MAX_DIM-1];
logic [BUS_WIDTH-1:0] flags, data;
logic unsigned [1:0] m_dim_o, n_dim_o, k_dim_o;

// assign small-width packed dimension encodings (as used by your control register)
assign m_dim_o = m_dim - 1;
assign n_dim_o = n_dim - 1;
assign k_dim_o = k_dim - 1;

// Performance counters
longint total_macs = 0; // 64-bit accumulator for MAC ops
real clk_period_ns = CLK_NS;
real sim_time_ns;
real total_cycles;
real active_cycles;
real target_freq_hz = (1e9 / CLK_NS);

// Active cycle monitor (count cycles where busy_o is asserted)
initial begin
    active_cycles = 0;
    forever begin
        @(posedge intf.clk_i);
        if (intf.busy_o) active_cycles++;
    end
end

// ------------------------ reset & file open ------------------------
task do_reset();
begin
    wait(~intf.rst_ni); // wait reset asserted
    intf.paddr_i  = '0;
    intf.penable_i= 1'b0;
    intf.psel_i   = 1'b0;
    intf.pstrb_i  = '0;
    intf.pwdata_i = '0;
    intf.pwrite_i = 1'b0;

    total_errors = 0;
    total_correct = 0;
    mat_a = '0;
    mat_b = '0;
    line_number = 0;
    i = 0; j = 0; k = 0; p = 0;
    count_right = 0;
    count_error = 0;
    n_dim = 0; k_dim = 0; m_dim = 0;
    flags = '0;
    incorrect_flag = 0;
    total_macs = 0;

    for (int ii = 0; ii < MAX_DIM; ii++) begin
        matA_lines[ii] = '0;
        matB_lines[ii] = '0;
        for (int jj = 0; jj < MAX_DIM; jj++) begin
            matA[ii][jj] = '0;
            matB[ii][jj] = '0;
            matC[ii][jj] = '0;
        end
    end

    open_txt_files();
    read_parameters(); // checks DW, BW, AW, SPN against package
end
endtask

task do_local_reset();
begin
    mat_a = '0;
    mat_b = '0;
    line_number = 0;
    i = 0; j = 0; k = 0; p = 0;
    count_right = 0;
    count_error = 0;
    n_dim = 0; k_dim = 0; m_dim = 0;
    flags = '0;
    for (int ii = 0; ii < MAX_DIM; ii++) begin
        matA_lines[ii] = '0;
        matB_lines[ii] = '0;
        for (int jj = 0; jj < MAX_DIM; jj++) begin
            matA[ii][jj] = '0;
            matB[ii][jj] = '0;
            matC[ii][jj] = '0;
        end
    end
end
endtask

// ------------------------ memory bus operations ------------------------
task write_mat_a(input logic [BUS_WIDTH-1:0] mat_a_in, input logic [1:0] line_number_in);
begin
    @(posedge intf.clk_i);
        intf.psel_i = 1;
        intf.paddr_i = 16'h0004 + 16'h0020 * line_number_in;
        intf.pwrite_i = 1;
        intf.pwdata_i = mat_a_in;
        intf.pstrb_i = {MAX_DIM{1'b1}};
    @(posedge intf.clk_i);
        intf.penable_i = 1;
    @(posedge intf.clk_i);
        intf.penable_i = 0;
        intf.psel_i = 0;
end
endtask

task write_mat_b(input logic [BUS_WIDTH-1:0] mat_b_in, input logic [1:0] line_number_in);
begin
    @(posedge intf.clk_i);
        intf.psel_i = 1;
        intf.paddr_i = 16'h0008 + 16'h0020 * line_number_in;
        intf.pwrite_i = 1;
        intf.pwdata_i = mat_b_in;
        intf.pstrb_i = {MAX_DIM{1'b1}};
    @(posedge intf.clk_i);
        intf.penable_i = 1;
    @(posedge intf.clk_i);
        intf.penable_i = 0;
        intf.psel_i = 0;
end
endtask

task write_to_control(input logic start_bit, input logic mode_bit,
                      input logic [1:0] write_target, input logic [1:0] read_target);
begin
    @(posedge intf.clk_i);
        intf.psel_i = 1;
        intf.paddr_i = 16'h0000;
        intf.pwrite_i = 1;
        intf.pwdata_i = {{(BUS_WIDTH-14){1'b0}}, m_dim_o, k_dim_o, n_dim_o, 2'b0, read_target, write_target, mode_bit, start_bit};
        intf.pstrb_i = {MAX_DIM{1'b1}};
    @(posedge intf.clk_i);
        intf.penable_i = 1;
    @(posedge intf.clk_i);
        intf.psel_i = 0;
        intf.penable_i = 0;
        intf.pwrite_i = 0;
end
endtask

task write_to_mem(input logic [ADDR_WIDTH-1:0] address, input logic [BUS_WIDTH-1:0] data_in);
begin
    @(posedge intf.clk_i);
        intf.psel_i = 1;
        intf.paddr_i = address;
        intf.pwrite_i = 1;
        intf.pwdata_i = data_in;
        intf.pstrb_i = {MAX_DIM{1'b1}};
    @(posedge intf.clk_i);
        intf.penable_i = 1;
    @(posedge intf.clk_i);
        intf.penable_i = 0;
        intf.psel_i = 0;
end
endtask

task read_from_mem(input logic [ADDR_WIDTH-1:0] address, output logic [BUS_WIDTH-1:0] data_out);
begin
    @(posedge intf.clk_i);
        intf.psel_i = 1;
        intf.paddr_i = address;
        intf.pwrite_i = 0;
    @(posedge intf.clk_i);
        intf.penable_i = 1;
        wait (intf.pready_o);
        data_out = intf.prdata_o;
    @(posedge intf.clk_i);
        intf.penable_i = 0;
        intf.psel_i = 0;
end
endtask

task read_entire_sp();
begin
    for (i = 0; i < n_dim*m_dim; i = i + 1) begin
        @(posedge intf.clk_i);
            intf.psel_i = 1;
            intf.paddr_i = 16'h0010 + 16'h0020 * i;
            intf.pwrite_i = 0;
        @(posedge intf.clk_i);
            intf.penable_i = 1;
            wait (intf.pready_o);
            matC_from_sp[i] = intf.prdata_o;
        @(posedge intf.clk_i);
            intf.penable_i = 0;
            intf.psel_i = 0;
    end
end
endtask

task read_flags();
begin
    @(posedge intf.clk_i);
        intf.psel_i = 1;
        intf.paddr_i = 16'h000c;
        intf.pwrite_i = 0;
    @(posedge intf.clk_i);
        intf.penable_i = 1;
        wait (intf.pready_o);
        flags = intf.prdata_o;
    @(posedge intf.clk_i);
        intf.penable_i = 0;
        intf.psel_i = 0;
end
endtask

// ------------------------ file IO ------------------------
task open_txt_files();
begin
    mat_a_fd = $fopen(MAT_A, "r");
    if (mat_a_fd == 0) $fatal(1, $sformatf("[STIMULUS] Failed to open %s", MAT_A));
    mat_b_fd = $fopen(MAT_B, "r");
    if (mat_b_fd == 0) $fatal(1, $sformatf("[STIMULUS] Failed to open %s", MAT_B));
    mat_c_fd = $fopen(MAT_C, "r");
    if (mat_c_fd == 0) $fatal(1, $sformatf("[STIMULUS] Failed to open %s", MAT_C));
    parameters_fd = $fopen(PARAMETERS, "r");
    if (parameters_fd == 0) $fatal(1, $sformatf("[STIMULUS] Failed to open %s", PARAMETERS));
    dimensions_fd = $fopen(DIMENSIONS, "r");
    if (dimensions_fd == 0) $fatal(1, $sformatf("[STIMULUS] Failed to open %s", DIMENSIONS));
end
endtask

task close_files();
begin
    if (mat_a_fd) $fclose(mat_a_fd);
    if (mat_b_fd) $fclose(mat_b_fd);
    if (mat_c_fd) $fclose(mat_c_fd);
    if (parameters_fd) $fclose(parameters_fd);
    if (dimensions_fd) $fclose(dimensions_fd);
end
endtask

task read_parameters();
begin
    read_line_fd = $fgets(line, parameters_fd);
    if (read_line_fd == 0) $fatal(1, $sformatf("[STIMULUS] Failed reading parameters line"));
    assign_line_fd = $sscanf(line, "DW=%0d,BW=%0d,AW=%0d,SPN=%0d", DW, BW, AW, SPN);
    if (assign_line_fd == 0) $fatal(1, $sformatf("[STIMULUS] Failed assigning parameters line to variables"));

    if (DW != DATA_WIDTH) $fatal("[STIMULUS] Read DW= %2d != Defined DW= %2d", DW, DATA_WIDTH);
    if (BW != BUS_WIDTH) $fatal("[STIMULUS] Read BW= %2d != Defined BW= %2d", BW, BUS_WIDTH);
    if (AW != ADDR_WIDTH) $fatal("[STIMULUS] Read AW= %2d != Defined AW= %2d", AW, ADDR_WIDTH);
    if (SPN != SP_NTARGETS) $fatal("[STIMULUS] Read SPN= %2d != Defined SPN= %2d", SPN, SP_NTARGETS);
end
endtask

// read_dimensions now returns bit: 1 => read fine, 0 => EOF (no line)
function bit read_dimensions();
begin
    read_line_fd = $fgets(line, dimensions_fd);
    if (read_line_fd == 0) begin
        $display("[STIMULUS] End of dimensions file reached. No more matrices to process.");
        return 0;
    end

    assign_line_fd = $sscanf(line, "n_dim=%0d,k_dim=%0d,m_dim=%0d", n_dim, k_dim, m_dim);
    if (assign_line_fd != 3) $fatal("[STIMULUS] Failed parsing dimensions line: %s", line);
    return 1;
end
endfunction

task read_matrices();
begin
    // read A lines
    for (int ii = 0; ii < n_dim; ii++) begin
        read_line_fd = $fgets(line, mat_a_fd);
        if (read_line_fd == 0) $fatal(1, $sformatf("[STIMULUS] Failed reading matrixA line"));
        case (k_dim)
            1: begin assign_line_fd = $sscanf(line, "%d\n", matA[ii][0]); matA_lines[ii] <= matA[ii][0]; end
            2: begin assign_line_fd = $sscanf(line, "%d %d\n", matA[ii][0], matA[ii][1]); matA_lines[ii] <= {matA[ii][1], matA[ii][0]}; end
            3: begin assign_line_fd = $sscanf(line, "%d %d %d\n", matA[ii][0], matA[ii][1], matA[ii][2]); matA_lines[ii] <= {matA[ii][2], matA[ii][1], matA[ii][0]}; end
            4: begin assign_line_fd = $sscanf(line, "%d %d %d %d\n", matA[ii][0], matA[ii][1], matA[ii][2], matA[ii][3]); matA_lines[ii] <= {matA[ii][3], matA[ii][2], matA[ii][1], matA[ii][0]}; end
            default: $fatal(1, "[STIMULUS] Unexpected K value while reading matrixA");
        endcase
        if (assign_line_fd == 0) $fatal(1, $sformatf("[STIMULUS] Failed assigning matrixA line to variables"));
    end

    // read B lines
    for (int ii = 0; ii < m_dim; ii++) begin
        read_line_fd = $fgets(line, mat_b_fd);
        if (read_line_fd == 0) $fatal(1, $sformatf("[STIMULUS] Failed reading matrixB line"));
        case (k_dim)
            1: begin assign_line_fd = $sscanf(line, "%d\n", matB[ii][0]); matB_lines[ii] <= matB[ii][0]; end
            2: begin assign_line_fd = $sscanf(line, "%d %d\n", matB[ii][0], matB[ii][1]); matB_lines[ii] <= {matB[ii][1], matB[ii][0]}; end
            3: begin assign_line_fd = $sscanf(line, "%d %d %d\n", matB[ii][0], matB[ii][1], matB[ii][2]); matB_lines[ii] <= {matB[ii][2], matB[ii][1], matB[ii][0]}; end
            4: begin assign_line_fd = $sscanf(line, "%d %d %d %d\n", matB[ii][0], matB[ii][1], matB[ii][2], matB[ii][3]); matB_lines[ii] <= {matB[ii][3], matB[ii][2], matB[ii][1], matB[ii][0]}; end
            default: $fatal(1, "[STIMULUS] Unexpected K value while reading matrixB");
        endcase
        if (assign_line_fd == 0) $fatal(1, $sformatf("[STIMULUS] Failed assigning matrixB line to variables"));
    end

    // read C golden
    for (int ii = 0; ii < n_dim; ii++) begin
        read_line_fd = $fgets(line, mat_c_fd);
        if (read_line_fd == 0) $fatal(1, $sformatf("[STIMULUS] Failed reading matrixC line"));
        case (m_dim)
            1: assign_line_fd = $sscanf(line, "%d\n", matC[ii][0]);
            2: assign_line_fd = $sscanf(line, "%d %d\n", matC[ii][0], matC[ii][1]);
            3: assign_line_fd = $sscanf(line, "%d %d %d\n", matC[ii][0], matC[ii][1], matC[ii][2]);
            4: assign_line_fd = $sscanf(line, "%d %d %d %d\n", matC[ii][0], matC[ii][1], matC[ii][2], matC[ii][3]);
            default: $fatal(1, "[STIMULUS] Unexpected M value while reading matrixC");
        endcase
        if (assign_line_fd == 0) $fatal(1, $sformatf("[STIMULUS] Failed assigning matrixC line to variables"));
    end
end
endtask

task automatic compare_golden();
    int max_log_mismatch = 16;
    int logged = 0;
    int local_correct = 0;
    int local_wrong = 0;

    logic signed [BUS_WIDTH-1:0] spv;
    logic signed [BUS_WIDTH-1:0] glv;

    for (int kk = 0; kk < n_dim; kk++) begin
        for (int pp = 0; pp < m_dim; pp++) begin

            spv = matC_from_sp[kk*m_dim + pp];
            glv = matC[kk][pp];

            if (spv === glv) begin
                local_correct++;
            end
            else begin
                local_wrong++;

                if (logged < max_log_mismatch) begin
                    $display("[STIMULUS][MISMATCH] mat %0d pos (%0d,%0d): sp=%0d golden=%0d",
                             count, kk, pp, spv, glv);
                    logged++;
                end
            end

            // Optional flag validation
            if (((spv > (2**(2*DATA_WIDTH-1)-1) || spv < -2**(2*DATA_WIDTH-1)) && ~flags[kk*m_dim+pp]) ||
                ((spv <= (2**(2*DATA_WIDTH-1)-1) && spv >= -2**(2*DATA_WIDTH-1)) && flags[kk*m_dim+pp])) begin
                $display("[STIMULUS][FLAG_ERR] pos (%0d,%0d): sp=%0d flag=%0d",
                         kk, pp, spv, flags[kk*m_dim+pp]);
            end
        end
    end

    // Update global totals
    total_correct += local_correct;
    total_errors  += local_wrong;

    if (local_wrong == 0)
        $display("[STIMULUS] Matrix #%0d OK (%0d elements)", count, local_correct);
    else
        $display("[STIMULUS] Matrix #%0d FAIL: correct=%0d wrong=%0d",
                 count, local_correct, local_wrong);
endtask

task matmul_check_golden(input logic mode_bit,
    input logic [1:0] write_target, read_target);

begin
    if (!(write_target < SP_NTARGETS && read_target < SP_NTARGETS))
        $fatal("[STIMULUS] Impossible read_target or write_target");

    do_local_reset();

    // *** CRITICAL FIX ***
    if (!read_dimensions()) begin
        $display("[STIMULUS] No more dimensions available.");
        return;
    end

    read_matrices();

    @(posedge intf.clk_i);

    for (i = 0; i < n_dim; i++)
        write_mat_a(matA_lines[i], i);

    for (j = 0; j < m_dim; j++)
        write_mat_b(matB_lines[j], j);

    write_to_control(1, mode_bit, write_target, read_target);

    wait(intf.busy_o);
    wait(!intf.busy_o);

    read_entire_sp();
    read_flags();
    compare_golden();
end
endtask

// ------------------------ driver : one iteration ------------------------
task process_one(output bit continue_flag);
begin
    // read dimensions (function) – SAFE
    if (!read_dimensions()) begin
        continue_flag = 0;
        return;
    end

    // read matrices for these dimensions – TASK → SAFE in task
    read_matrices();

    // accumulate MAC ops
    total_macs += longint'(n_dim) * longint'(k_dim) * longint'(m_dim);

    // run golden check (task with delays) – SAFE in task
    matmul_check_golden(0, 2'b01, 2'b01);

    count++;

    // Progress print every 50
    if ((count % 50) == 0) begin
        if (total_correct + total_errors == 0)
            $display("[Progress] %0d matrices done... Current accuracy = -- (no results yet)", count);
        else
            $display("[Progress] %0d matrices done... Current accuracy = %0.2f%%",
                count, (total_correct * 100.0) / (total_correct + total_errors));
    end

    $display("total correct=%0d wrong=%0d matrices=%0d",
        total_correct, total_errors, count);

    @(posedge intf.clk_i); // SAFE in task

    continue_flag = 1;
end
endtask

// ------------------------ metrics & summary ------------------------
task print_evaluation_summary();
    real accuracy_percent;
    real error_percent;
    real gflops;
    real utilization_percent;
begin
    sim_time_ns = $time;
    total_cycles = sim_time_ns / clk_period_ns;

    if ((total_correct + total_errors) == 0) begin
        accuracy_percent = 0.0;
        error_percent = 0.0;
    end else begin
        accuracy_percent = (total_correct * 100.0) / (total_correct + total_errors);
        error_percent = (total_errors * 100.0) / (total_correct + total_errors);
    end

    gflops = 0.0;
    if (total_cycles > 0) begin
        gflops = (total_macs / total_cycles) * (target_freq_hz / 1e9);
    end

    utilization_percent = 0.0;
    if (total_cycles > 0) utilization_percent = (active_cycles * 100.0) / total_cycles;

    $display("\n=============================================================");
    $display(" AI ACCELERATOR - MATRIX MULTIPLIER PERFORMANCE REPORT ");
    $display("=============================================================");
    $display("Total Matrices Checked          : %0d", count);
    $display("Total Correct Results           : %0d", total_correct);
    $display("Total Wrong Results             : %0d", total_errors);
    $display("-------------------------------------------------------------");
    $display("Accuracy                        : %0.2f %%", accuracy_percent);
    $display("Error Rate                      : %0.2f %%", error_percent);
    $display("-------------------------------------------------------------");
    $display("MAC Operations (Total)          : %0d", total_macs);
    $display("Estimated Throughput            : %0.3f GFLOPS", gflops);
    $display("Datapath Utilization            : %0.2f %%", utilization_percent);
    $display("-------------------------------------------------------------");
    $display("Simulation End Time             : %0t ns", $time);
    $display("=============================================================\n");
end
endtask

task dump_sample(int idx);
    int r,c;
begin
    $display("--- SAMPLE MATRIX #%0d (n=%0d k=%0d m=%0d) ---", idx, n_dim, k_dim, m_dim);
    for (r=0; r<n_dim; r++) begin
        $write("A[%0d]: ", r);
        for (c=0; c<k_dim; c++) $write("%0d ", matA[r][c]);
        $write("\n");
    end
    for (r=0; r<m_dim; r++) begin
        $write("B[%0d]: ", r);
        for (c=0; c<k_dim; c++) $write("%0d ", matB[r][c]);
        $write("\n");
    end
    $display("Golden C (matC):");
    for (r=0; r<n_dim; r++) begin
        for (c=0; c<m_dim; c++) $write("%0d ", matC[r][c]);
        $write("\n");
    end
    $display("SP output (matC_from_sp):");
    for (r=0; r<n_dim; r++) begin
        for (c=0; c<m_dim; c++) $write("%0d ", matC_from_sp[r*m_dim+c]);
        $write("\n");
    end
end
endtask

// ------------------------ main stimulus ------------------------
initial begin: main_stimulus
    do_reset();
    @(posedge intf.clk_i);

    count = 0;

	while (cont) begin
    	process_one(cont);
	end

    // final summary & cleanup
    $display("[STIMULUS] All dimensions processed or dimensions file empty. Printing final summary...");
    print_evaluation_summary();
    close_files();
    $finish;
end

endmodule
