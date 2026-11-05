# MOCAST 2027 — Conference & Paper Planning Guide

## 1. Conference Overview & Key Dates

- **Conference:** 16th International Conference on Modern Circuits and Systems Technologies (MOCAST 2027) on Electronics and Communications
- **Location:** Research Dissemination Center (KEDEA), Aristotle University of Thessaloniki (AUTH), Thessaloniki, Greece
- **Conference Dates:** 23–25 June 2027
- **Paper Submission Deadline:** **12 February 2027 (11:59 PM)**
- **Website:** http://mocast.physics.auth.gr/
- **Indexing & Sponsorship:** Technically Sponsored by IEEE (Greece Section & CAS/SSC Joint Chapter). Accepted papers are included in the **IEEE Xplore Digital Library** and indexed by **EI**.
- **Typical Format:** 4 pages, standard IEEE two-column conference format.

---

## 2. Why MOCAST 2027 Fits the Ascon-128 Project

1. **Direct Track Alignment:**
   - **Digital Circuits Track:** Explicitly solicits *"Security and encryption circuits"*, *"VLSI circuits and Systems"*, *"I/O and inter-chip communication"*, *"FPGAs"*, and *"Techniques for energy efficient and high performance digital circuits"*.
   - **Systems and Applications / High Performance Embedded Systems Tracks:** Covers *"VLSI Systems, System on Chip (SoC), CAD tools, Embedded systems, System architectures"*.
   - **Education in Circuits, Systems and Communications:** Very welcoming to university-led ASIC tapeouts and comparative EDA/hardware studies.
2. **Timeliness of Ascon-128:**
   - Ascon was recently standardized by NIST in **SP 800-232** as the standard for Lightweight Cryptography (AEAD and Hashing), making physical hardware evaluations across ASIC and FPGA technologies highly relevant to IEEE reviewers.
3. **Strong Project Maturity:**
   - The RTL (`tt_um_ascon.v`, `ascon_encryption.v`, `ascon_round.v`) and Cocotb verification suite (`test/test.py`) are already complete and verified against NIST golden test vectors.
   - Physical ASIC layouts have already been generated across two open-source PDKs: **SkyWater 130nm (`sky130A`)** and **GlobalFoundries 180nm (`gf180mcuD`)**.
   - Parallel work on **multiple FPGA families** provides immediate silicon validation and cross-platform synthesis benchmarks without waiting for fabricated ASIC chips to return.

---

## 3. Recommended Paper Strategy & Narrative

Rather than presenting a basic RTL summary of the Ascon algorithm, an IEEE circuits paper should focus on **architectural trade-offs, PPA (Power, Performance, Area) optimization, and cross-platform (Multi-ASIC + Multi-FPGA) implementation**.

### Proposed Working Titles
- **Option 1 (Comprehensive ASIC + FPGA):** *"Design, Pin-Constrained Microarchitecture, and Cross-Platform Implementation of an Ascon-128 AEAD Accelerator Across Multi-Node ASICs and FPGAs"*
- **Option 2 (ASIC & EDA Focus):** *"Design and Cross-PDK Physical Implementation of an Area-Optimized Ascon-128 AEAD Accelerator in 130nm and 180nm CMOS"*
- **Option 3 (IoT Co-Processor Focus):** *"A Compact Memory-Mapped Ascon-128 Hardware Security Co-Processor for Pin- and Area-Constrained IoT Systems"*

### Core Technical Angles to Combine

#### Angle 1: Architectural Trade-offs & Datapath Optimization (Inside the Core)
- **Single-Cycle Combinational Permutation Engine (`ascon_round.v`):** Evaluates one full 320-bit round per clock cycle using 64 parallel 5-bit bit-sliced S-boxes (`p_S`), constant addition (`p_C`), and 64-bit circular right rotations (`p_L`).
- **Round Reuse Across AEAD Phases (`ascon_encryption.v`):** Reuses a single combinational `ascon_round` instance for both $p^{12}$ (Initialization and Finalization) and $p^8$ (Associated Data and Plaintext absorption) by dynamically offsetting the 4-bit round counter (`i <= 4'd0` vs. `i <= 4'd4`).
- **Shared Rate Datapath & On-the-Fly Framing:** Uses a single shared 128-bit XOR array (`rate_xored`) for AD absorption, PT absorption, and CT output, alongside combinational hardware padding (`0x80` byte insertion via `pad()`) and partial-block ciphertext truncation (`truncate()`).

#### Angle 2: Full-Chip Microarchitecture for Pin-Constrained IoT (`tt_um_ascon.v`)
- **Solving the I/O Bottleneck:** A full-width Ascon-128 interface would require hundreds of pins (128-bit Key, 128-bit Nonce, 128-bit AD/PT input, 128-bit CT output, 128-bit Tag output). Our wrapper fits the entire accelerator into **24 active pins** (`8-bit` write bus `ui_in`, `8-bit` read bus `uo_out`, and `6-bit` control/address `uio_in[5:0]`) within a `3x2` Tiny Tapeout tile budget.
- **Shared 128-bit Buffer Reuse:** Instead of separate shadow registers for Nonce, Key, AD, PT, and CT (which would cost 640+ flip-flops), a single 128-bit `buffer` register is time-multiplexed across all input phases and captures the output Ciphertext (`ct_valid`), while the 128-bit Authentication Tag (`T`) is muxed directly from `state[127:0]`.
- **Clock-Domain & Strobe Synchronization:** Includes a 2-flip-flop synchronizer and rising-edge detector (`write_pulse`) on `write_raw` (`uio_in[6]`) so a slower asynchronous host MCU (RP2040) or external FPGA can safely drive transactions.

#### Angle 3: Cross-Platform PPA Evaluation (Multi-PDK ASIC + Multi-FPGA + Optional Commercial EDA)
- **Open-Source ASIC Comparison (`sky130A` vs. `gf180mcuD`):** Direct benchmark of the exact same Verilog RTL synthesized and placed-and-routed via OpenLane/LibreLane across SkyWater 130nm (`3x2` tiles $\approx 500 \times 216\ \mu\text{m}$) and GlobalFoundries 180nm (`3x2` tiles $\approx 1020 \times 320\ \mu\text{m}$).
- **Cross-PDK Timing Closure & Interconnect Constraints (`50 MHz` on `sky130A` vs. `25 MHz` on `gf180mcuD`):**
  - Both implementations route cleanly within a `3x2` tile budget (`PL_TARGET_DENSITY_PCT = 60%`) with **0 DRC violations** and pass gate-level verification.
  - However, in `gf180mcuD`, `Metal1` is consumed internally by standard cells (`0` global routing tracks), leaving only **3 metal routing layers (`Metal2–Metal4`)** for signal routing across a $2\times$ wider tile footprint. Consequently, the high-fanout 64-bit circular rotation nets ($p_L$) must detour around congestion across 3 layers, increasing interconnect $RC$ delay.
  - Compounded by 180nm (3.3V/5.0V) gate propagation delays through the single-cycle unrolled round logic (64 parallel S-boxes + diffusion XOR trees + multiplexers), this results in a critical path delay of $\approx 25\text{ ns}$ (and triggers aggressive resizer buffer insertion if over-constrained at `20 ns`).
  - Therefore, while the faster 130nm (1.8V) node with 4 signal routing layers (`li1` + `met1–met4` in `sky130A`) easily meets timing at **50 MHz (`20 ns`)**, the `gf180mcuD` implementation closes timing cleanly at **25 MHz (`40 ns`)** with zero setup violations.
- **Optional Commercial vs. Open-Source EDA Comparison:** If synthesized in **Synopsys Design Compiler / IC Compiler**, compare standard-cell utilization, timing slack, and power estimation between commercial EDA and open-source OpenROAD flows.
- **Multi-FPGA Architectural Mapping (Partner's Work):** Compare how LUT-based FPGA fabrics (e.g., Xilinx Artix-7, Zynq, Spartan, Intel Cyclone, or Lattice) map the 64 parallel 5-input S-boxes (`p_S` maps naturally into 5-LUTs/6-LUTs) versus discrete logic gates in 130nm/180nm standard-cell ASIC libraries. Evaluate both the standalone `encryption` core (128-bit native bus) and the pin-multiplexed `tt_um_ascon` top-level wrapper on FPGA.

---

## 4. Proposed 4-Page IEEE Paper Outline & Work Split

| Section | Page Budget | Lead | Key Contents |
| :--- | :---: | :---: | :--- |
| **Abstract** | ~150 words | Both | Problem statement, Ascon-128 NIST SP 800-232 context, summary of compact architecture, and key ASIC (130nm/180nm) + FPGA PPA metrics. |
| **I. Introduction** | 0.75 p | Both | Need for lightweight AEAD in IoT; hardware challenges of 320-bit state and I/O pin limits; summary of contributions. |
| **II. Hardware Architecture** | 1.25 p | Shlomo & Partner | Top-level block diagram (`tt_um_ascon` + `encryption` + `ascon_round`); 8-state FSM diagram (`I_NONCE` to `F_PERMUTATE`); register map table; cycle-latency formula (core permutation cycles vs. 8-bit bus transfer cycles). |
| **III. ASIC & FPGA Implementations** | 1.00 p | **III-A: Shlomo**<br>**III-B: Partner** | **III-A (ASIC):** OpenLane/LibreLane (and optional Synopsys) flow on `sky130A` and `gf180mcuD`; side-by-side GDSII physical layout views; Cocotb verification.<br>**III-B (FPGA):** Synthesis & P&R across multiple FPGA families; LUT/FF mapping of S-boxes and diffusion layer; on-board hardware verification setup. |
| **IV. Experimental Results & Comparison** | 0.75 p | Both | **Table I:** ASIC PPA (`sky130A` vs. `gf180mcuD` [vs. Synopsys]).<br>**Table II:** Multi-FPGA resource utilization (LUTs, FFs, Slices, $f_{\max}$, Power, Mbps/LUT).<br>**Table III:** Comparison with recent IEEE Ascon hardware implementations (GE, Throughput, Mbps/kGE). |
| **V. Conclusion** | 0.25 p | Both | Summary of findings and future post-silicon testing plans. |

---

## 5. Metrics Checklist to Extract for Tables

### A. ASIC Metrics (Shlomo — `sky130A`, `gf180mcuD`, and optional Synopsys)
- [ ] **Total Standard Cells & Gate Equivalents (GE):** Total area divided by 2-input NAND gate area (`nand2_1`) in each PDK.
- [ ] **Area Breakdown:** Combinational logic area (`ascon_round`, muxes, padding) vs. Sequential area (320-bit `state`, 128-bit `k`, 128-bit `buffer`, FSM/control FFs).
- [ ] **Silicon Footprint & Utilization:** Die/tile dimensions ($\mu\text{m} \times \mu\text{m}$), core area ($\mu\text{m}^2$), and placement density (%).
- [ ] **Timing (STA):** Critical path delay (ns), maximum clock frequency $f_{\max}$ (MHz) across nominal/worst corners, and slack at the 50 MHz target clock.
- [ ] **Power Estimation:** Internal, switching, and leakage power (mW) at 50 MHz and at $f_{\max}$; Energy efficiency (pJ/bit).

### B. FPGA Metrics (Partner — Across Target FPGA Families)
- [ ] **Resource Utilization:** LUTs, Flip-Flops (FFs), Slices / ALMs, and Muxes (reported for both standalone `encryption` and wrapped `tt_um_ascon`).
- [ ] **Timing:** Maximum synthesized clock frequency $f_{\max}$ (MHz) and worst-case combinational path delay through `ascon_round`.
- [ ] **Power:** Dynamic and static power from vendor power analyzers (e.g., Vivado / Quartus).
- [ ] **Efficiency Metrics:** Throughput (Mbps) and Throughput-per-Area (Mbps/LUT or Mbps/Slice).

### C. Cycle & Throughput Formulas (Shared)
- **Core Permutation Cycles:**
  - Initialization: $12\text{ cycles}$ ($p^{12}$)
  - Associated Data: $8\text{ cycles/block}$ ($p^8$)
  - Plaintext / Ciphertext: $8\text{ cycles/block}$ ($p^8$ for intermediate blocks)
  - Finalization: $12\text{ cycles}$ ($p^{12}$)
- **Bus I/O Overhead (`tt_um_ascon` 8-bit wrapper vs. `encryption` 128-bit native core):**
  - Quantify the exact cycle ratio between native 128-bit bus operation and 8-bit memory-mapped host transfers.

---

## 6. Backward Schedule to Submission (Deadline: Feb 12, 2027)

- **November – Mid-December 2026:**
  - Finalize scope with Uri during project meeting (confirm whether to include Synopsys alongside `sky130A`, `gf180mcuD`, and FPGAs).
  - Partner completes synthesis and implementation runs across the selected FPGA boards/families.
  - Extract full synthesis, STA, and power reports from the existing `tt-ascon-sky` and `tt-ascon-gf` runs.
- **Mid-December 2026 – Mid-January 2027:**
  - Run any additional EDA comparisons (e.g., Synopsys or standalone `encryption` vs. wrapped `tt_um_ascon` synthesis).
  - Generate publication-quality block diagrams, FSM diagrams, GDSII layout renders, and consolidated PPA tables.
- **Mid-January – February 12, 2027:**
  - Draft the 4-page manuscript in the IEEE LaTeX conference template.
  - Review and iterate with Uri.
  - Submit via the MOCAST 2027 portal before **12 February 2027**.

