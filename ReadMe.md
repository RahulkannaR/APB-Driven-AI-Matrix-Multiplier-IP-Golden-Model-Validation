# ⚡ APB-Driven AI Matrix Multiplier IP — Golden Model Validation

This repository contains the complete **APB-Controlled Matrix Multiplication Hardware IP**, combined with a **Python Golden Model** and a **SystemVerilog Verification Environment**. The design targets ASIC/FPGA compute accelerators and enables full APB-driven software–hardware co-validation.

> 🧩 Design Type: RTL Compute IP + APB Slave Interface  
> 🧪 Verification: Python Golden Model + SystemVerilog TB  
> 🚀 Use Case: AI acceleration, DSP kernels, custom compute engines  

---

## 🧠 Project Highlights

- APB Register Interface for input/output & control  
- Parameterizable Matrix-Multiplication compute core  
- Processing Element (MAC) based architecture  
- Python Golden Model generating expected results  
- SystemVerilog testbench with stimulus, checker, and coverage  
- Bit-exact RTL vs Golden Model validation  

---

## 📁 Repository Structure

APB-Driven-AI-Matrix-Multiplier-IP/  
├── Design_RTL/  
│   ├── apb_slave.v  
│   ├── matmul.v  
│   ├── matmul_calc.v  
│   ├── pe_module.v  
│   ├── mem.v  
│   ├── design.sv  
│   └── headers.vh  
│  
├── Testbench/  
│   ├── testbench.sv  
│   ├── matmul_pkg.sv  
│   ├── matmul_stimulus.sv  
│   ├── matmul_checker.sv  
│   ├── matmul_coverage.sv  
│   └── matmul_tester.sv  
│  
├── Golden_Model/  
│   ├── Golden_Model.py  
│   ├── matrix_gen.py  
│   └── result_matrix.txt  
│  
├── Input_Files/  
│   ├── matrixA.txt  
│   ├── matrixB.txt  
│   ├── matrixC.txt  
│   ├── dimensions.txt  
│   └── parameters.txt  
│  
├── Results/  
│   ├── run.log  
│   ├── qrun.log  
│   ├── result_matrix.txt  
│   └── comparisons/  
│  
├── scripts/  
│   ├── run.sh  
│   └── sim.do  
│  
└── README.md  

---

## 🚀 Getting Started

### Prerequisites

- Python 3.8+  
- SystemVerilog simulator  
- Python libraries (`numpy`, `pandas`)  

Install dependencies:  
pip install -r requirements.txt  

---

## 🔧 Running the Complete Flow

### Step 1 — Generate Matrices & Golden Output  
python3 Golden_Model/Golden_Model.py  

### Step 2 — Run RTL Simulation  
sh scripts/run.sh  

### Step 3 — Compare RTL Output with Golden Reference  
cat Results/run.log  
cat Results/comparisons/*  

### Step 4 — Optional: View Waveform  
vsim -do scripts/sim.do  

---

## 📊 Input Files Description

matrixA.txt      → Input A  
matrixB.txt      → Input B  
matrixC.txt      → Expected output  
dimensions.txt   → Matrix configuration  
parameters.txt   → PE count, memory size, APB map  

Both Python and SV TB read from the same files for consistency.

---

## 🧩 APB Operation Overview

1. Write matrices A & B via APB  
2. Configure operation through APB registers  
3. MAC array computes results  
4. Status register indicates done  
5. Read matrix C using APB reads  

---

## 🧪 Verification Notes

✔ Checker compares RTL output vs Golden Model  
✔ Mismatch logs stored in Results/comparisons/  
✔ Coverage inside matmul_coverage.sv  
✔ Stimulus generator performs APB read/write sequences  

---

## 📁 Results Folder

run.log           → Simulation output  
qrun.log          → Quick summary  
result_matrix.txt → RTL result  
comparisons/      → Difference reports  

---

## 🔮 Future Enhancements

• UVM environment  
• AXI4-Lite control interface  
• Pipelined systolic architecture  
• Fixed-point quantization support  
• Automated CI regressions  

---

## ✨ Author

R. Rahul  
Design & Verification Trainee  
APB/AXI • Compute Hardware • Python Golden Models • SystemVerilog  
Email: rahulkannavcet@gmail.com  

---

## 🔖 Keywords

APB, RTL, Matrix Multiplier, Python Golden Model, SystemVerilog,  
MAC, Compute IP, VLSI, ASIC, Hardware Acceleration, Verification
