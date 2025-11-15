<!-- ------------------------------------------------------------ -->
<!--        APB-Driven AI Matrix Multiplier IP — README           -->
<!-- ------------------------------------------------------------ -->

<h1 align="center">⚡ APB-Driven AI Matrix Multiplier IP  
Golden Model Validation Framework ⚡</h1>

<p align="center">
  <b>RTL Design • Python Golden Model • SystemVerilog Verification</b><br>
  APB-based hardware accelerator with end-to-end validation flow
</p>

---

## 🚀 Overview

This project implements a **Matrix Multiplication Hardware IP** with a complete:
- **APB Slave Register Interface**
- **Synthesizable RTL Compute Core**
- **Python Golden Model (Reference)**
- **SystemVerilog Testbench with Checking + Coverage**
- **Matrix Input Automation + Result Comparison**

Perfect for VLSI design, ASIC DV, and hardware-software co-validation.

---

## 📂 Repository Structure

```
APB-Driven-AI-Matrix-Multiplier-IP/
│
├── Design_RTL/           → Synthesizable RTL (SV/Verilog)
├── Testbench/            → SystemVerilog TB + verification
│     └── verification/   → (Optional) UVM or advanced checks
├── Golden_Model/         → Python reference implementation
├── Input_Files/          → Matrix A/B/C, dimensions, parameters
├── Documents/            → Notes, architecture diagrams, specs
├── Results/              → RTL output, logs, waveforms, comparisons
└── scripts/              → Shell/Tcl automation scripts
```

---

## 🧩 Architecture

```
                ┌──────────────────────────┐
                │          APB BUS         │
                └─────────────┬────────────┘
                              │
                       ┌──────▼──────┐
                       │  APB SLAVE  │
                       │ INTERFACE   │
                       └──────┬──────┘
                              │ control + data
        ┌─────────────────────▼─────────────────────┐
        │          MATRIX MULTIPLIER CORE           │
        │   (PE Array + Local Memory + MAC Units)   │
        └─────────────────────┬─────────────────────┘
                              │ result matrix
                       ┌──────▼──────┐
                       │  OUTPUT C   │
                       └─────────────┘
```

---

## 🛠️ RTL Modules

| File | Description |
|------|-------------|
| `apb_slave.v` | APB register map + control |
| `matmul.v` | Top-level wrapper |
| `matmul_calc.v` | Core compute engine |
| `pe_module.v` | Processing element (MAC) |
| `mem.v` | Internal storage buffer |
| `headers.vh` | Macros & parameters |
| `design.sv` | Structural integration |
| `parameters.txt` | Matrix configuration |

---

## 🧪 Testbench Components

| File | Role |
|------|------|
| `testbench.sv` | Top-level TB |
| `matmul_pkg.sv` | Shared TB types |
| `matmul_stimulus.sv` | Drives APB writes/reads |
| `matmul_checker.sv` | RTL vs Golden comparison |
| `matmul_coverage.sv` | Functional coverage |
| `matmul_tester.sv` | Test scenario manager |

---

## 🧠 Python Golden Model

| File | Description |
|------|-------------|
| `Golden_Model.py` | Reference matrix multiplication |
| `matrix_gen.py` | Auto input generator |
| `result_matrix.txt` | Golden output |

Outputs from Python are fed into the SystemVerilog checker.

---

## 📥 Input Files

All inputs stored in `Input_Files/`:
- `matrixA.txt`  
- `matrixB.txt`  
- `matrixC.txt`  
- `dimensions.txt`  
- `parameters.txt`  

---

## ▶️ How to Run

### 1️⃣ Golden Model Generation
```
python3 Golden_Model/Golden_Model.py
```

### 2️⃣ Run RTL Simulation
```
sh scripts/run.sh
```

### 3️⃣ View Results
```
Results/run.log
Results/result_matrix.txt
Results/comparisons/
```

### 4️⃣ View Waveforms
```
vsim -do sim.do
```

---

## 📊 Results Directory
```
Results/
│── run.log
│── qrun.log
│── result_matrix.txt
│── waves/
└── comparisons/
```

---

## 🔮 Future Enhancements
- Full UVM Testbench  
- AXI4-Lite interface version  
- Pipelined systolic array core  
- Larger matrix dimension support  
- Fixed-point quantization improvements  

---

## 📜 License
MIT License

---

## ✨ Author
**Rahul Kanna R**  
Design Verification & RTL Engineer  
Expert in APB/AXI, UVM, Compute Hardware, Python Golden Models  

