`include "headers.vh"
import matmul_pkg::*;

module matmul_tester#(parameter string RESOURCE_BASE = "") ( matmul_interface intf);

import matmul_pkg::*;
wire rst = intf.rst_ni;

// Functional Coverage untoggle for checking coverage
// matmul_coverage u_cover (
//     .intf(intf)
// );

// Functional Checker untoggle for checker
// matmul_checker u_check (
//     .intf    (intf)
// );

  matmul_stimulus #(
  .MAT_A_FILE($sformatf("%s/matrix_a.txt", RESOURCE_BASE)), 
  .MAT_B_FILE($sformatf("%s/matrix_b.txt", RESOURCE_BASE))
) u_stim (.intf(intf));

initial begin: TB_INIT
    wait(rst); wait(!rst);

end

endmodule
