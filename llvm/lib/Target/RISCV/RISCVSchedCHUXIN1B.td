//==- RISCVSchedCHUXIN1B.td - CHUXIN1B Scheduling Definitions --*- tablegen -*-=//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//

/// c is true if mx has the worst case behavior compared to LMULs in MxList.
/// On the CHUXIN1B, the worst case LMUL is the Largest LMUL
/// and the worst case sew is the smallest SEW for that LMUL.
class CHUXIN1BIsWorstCaseMX<string mx, list<string> MxList> {
  defvar LLMUL = LargestLMUL<MxList>.r;
  bit c = !eq(mx, LLMUL);
}

/// c is true if mx and sew have the worst case behavior compared to LMULs in
/// MxList. On the CHUXIN1B, the worst case LMUL is the Largest LMUL
/// and the worst case sew is the smallest SEW for that LMUL.
class CHUXIN1BIsWorstCaseMXSEW<string mx, int sew, list<string> MxList,
                               bit isF = 0> {
  defvar LLMUL = LargestLMUL<MxList>.r;
  defvar SSEW = SmallestSEW<mx, isF>.r;
  bit c = !and(!eq(mx, LLMUL), !eq(sew, SSEW));
}

/// Number of DLEN parts = (LMUL * VLEN) / DLEN.
/// Since DLEN = VLEN / 2, Num DLEN parts = 2 * LMUL.
class CHUXIN1BGetCyclesDefault<string mx> {
  int c = !cond(
    !eq(mx, "M1") : 2,
    !eq(mx, "M2") : 4,
    !eq(mx, "M4") : 8,
    !eq(mx, "M8") : 16,
    !eq(mx, "MF2") : 1,
    !eq(mx, "MF4") : 1,
    !eq(mx, "MF8") : 1
  );
}

class CHUXIN1BGetCyclesNarrowing<string mx> {
  int c = !cond(
    !eq(mx, "M1") : 4,
    !eq(mx, "M2") : 8,
    !eq(mx, "M4") : 16,
    !eq(mx, "MF2") : 2,
    !eq(mx, "MF4") : 1,
    !eq(mx, "MF8") : 1
  );
}

class CHUXIN1BGetCyclesVMask<string mx> {
  int c = !cond(
    !eq(mx, "M1") : 1,
    !eq(mx, "M2") : 1,
    !eq(mx, "M4") : 1,
    !eq(mx, "M8") : 2,
    !eq(mx, "MF2") : 1,
    !eq(mx, "MF4") : 1,
    !eq(mx, "MF8") : 1
  );
}

/// VLDM and VSTM can't read/write more than 2 DLENs of data.
/// 2 DLENs when LMUL=8. 1 DLEN for all other DLENs
class CHUXIN1BGetMaskLoadStoreCycles<string mx> {
  int c = !cond(
    !eq(mx, "M8")  : 2,
    true : 1
  );
}

// Cycles for nf=2 segmented loads and stores are calculated using the
// formula (2 * VLEN * LMUL) / DLEN = 4 * LMUL
class CHUXIN1BGetCyclesSegmentedSeg2<string mx> {
  int c = !cond(
    !eq(mx, "M1") :  4,
    !eq(mx, "M2") :  8,
    !eq(mx, "M4") :  16,
    !eq(mx, "M8") :  32,
    !eq(mx, "MF2") : 2,
    !eq(mx, "MF4") : 1,
    !eq(mx, "MF8") : 1
  );
}

// Cycles for segmented loads and stores are calculated using the
// formula vl * ceil((SEW * nf) / DLEN), where SEW * nf is the segment size.
class CHUXIN1BGetCyclesSegmented<string mx, int sew, int nf> {
  defvar VLEN = 512;
  defvar DLEN = 256;
  // (VLEN * LMUL) / SEW
  defvar VLUpperBound  = !cond(
    !eq(mx, "M1") : !div(VLEN, sew),
    !eq(mx, "M2") : !div(!mul(VLEN, 2), sew),
    !eq(mx, "M4") : !div(!mul(VLEN, 4), sew),
    !eq(mx, "M8") : !div(!mul(VLEN, 8), sew),
    !eq(mx, "MF2") : !div(!div(VLEN, 2), sew),
    !eq(mx, "MF4") : !div(!div(VLEN, 4), sew),
    !eq(mx, "MF8") : !div(!div(VLEN, 8), sew),
  );
  // We can calculate ceil(a/b) using (a + b - 1) / b.
  defvar a = !mul(sew, nf);
  defvar b = DLEN;
  int c = !mul(VLUpperBound, !div(!sub(!add(a, b), 1), b));
}

class CHUXIN1BGetCyclesOnePerElement<string mx, int sew> {
  // FIXME: On CHUXIN1B, VLEN is 512. Although a user can request the compiler
  // to use a different VLEN, this model will not make scheduling decisions
  // based on the user specified VLEN.
  // c = ceil(VLEN / SEW) * LMUL
  // Note: c >= 1 since the smallest VLEN is 512 / 8 = 8, and the
  // largest division performed on VLEN is in MF8 case with division
  // by 8. Therefore, there is no need to ceil the result.
  int VLEN = !div(512, sew);
  int c = !cond(
    !eq(mx, "M1")  : VLEN,
    !eq(mx, "M2")  : !mul(VLEN, 2),
    !eq(mx, "M4")  : !mul(VLEN, 4),
    !eq(mx, "M8")  : !mul(VLEN, 8),
    !eq(mx, "MF2") : !div(VLEN, 2),
    !eq(mx, "MF4") : !div(VLEN, 4),
    !eq(mx, "MF8") : !div(VLEN, 8)
  );
}

class CHUXIN1BGetDivOrSqrtFactor<int sew> {
  int c = !cond(
    // TODO: Add SchedSEWSetFP upstream and remove the SEW=8 case.
    !eq(sew, 8) : 15,
    !eq(sew, 16) : 15,
    !eq(sew, 32) : 28,
    !eq(sew, 64) : 57
  );
}

/// Cycles for reductions take approximately VL*SEW/DLEN + 5(4 + log(DLEN/SEW))
/// cycles.
class CHUXIN1BGetReductionCycles<string mx, int sew> {
  // VLUpperBound*SEW/DLEN is equivalent to 2*LMUL since
  // VLUpperBound=(VLEN*LMUL)/SEW.
  defvar VLEN = 512;
  defvar DLEN = !div(VLEN, 2);
  defvar TwoTimesLMUL = !cond(
    !eq(mx, "M1") : 2,
    !eq(mx, "M2") : 4,
    !eq(mx, "M4") : 8,
    !eq(mx, "M8") : 16,
    !eq(mx, "MF2") : 1,
    !eq(mx, "MF4") : 1,
    !eq(mx, "MF8") : 1
  );
  int c = !add(
    TwoTimesLMUL,
    !mul(5, !add(4, !logtwo(!div(DLEN, sew))))
  );
}

/// Cycles for ordered reductions take approximatley 6*VL cycles
class CHUXIN1BGetOrderedReductionCycles<string mx, int sew> {
  defvar VLEN = 512;
  // (VLEN * LMUL) / SEW
  defvar VLUpperBound  = !cond(
    !eq(mx, "M1") : !div(VLEN, sew),
    !eq(mx, "M2") : !div(!mul(VLEN, 2), sew),
    !eq(mx, "M4") : !div(!mul(VLEN, 4), sew),
    !eq(mx, "M8") : !div(!mul(VLEN, 8), sew),
    !eq(mx, "MF2") : !div(!div(VLEN, 2), sew),
    !eq(mx, "MF4") : !div(!div(VLEN, 4), sew),
    !eq(mx, "MF8") : !div(!div(VLEN, 8), sew),
  );
  int c = !mul(6, VLUpperBound);
}

class CHUXIN1BAnyToGPRBypass<SchedRead read, int cycles = 2>
    : ReadAdvance<read, cycles, [WriteIALU, WriteIALU32,
                                 WriteShiftImm, WriteShiftImm32,
                                 WriteShiftReg, WriteShiftReg32,
                                 WriteIMul, WriteIMul32,
                                 WriteIDiv, WriteIDiv32,
                                 WriteIRem, WriteIRem32,
                                 WriteLDB, WriteLDH, WriteLDW, WriteLDD]>;

// CHUXIN1B machine model for scheduling and other instruction cost heuristics.
def CHUXIN1BModel : SchedMachineModel {
  let MicroOpBufferSize = 0; // Explicitly set to zero since CHUXIN1B is in-order.
  let IssueWidth = 1;        // 1 micro-op is dispatched per cycle.
  let LoadLatency = 5;       // 5 cycles for load if L1 cache hit.
  let MispredictPenalty = 13;// 13 cycles for branch misprediction.
  let CompleteModel = 0;
  let EnableIntervals = true;
  let UnsupportedFeatures = [HasStdExtZbbOrZbkb, HasStdExtZbkb, HasStdExtZbkc, HasStdExtZbkx,
                             HasStdExtZcmt, HasStdExtZknd, HasStdExtZkne,
                             HasStdExtZknh, HasStdExtZksed, HasStdExtZksh,
                             HasStdExtZfh,
                             HasStdExtZkr, HasStdExtZbs];
}

// The CHUXIN1B microarchitecture has three pipelines: A, B, V.
// Pipe A can handle memory, integer alu and vector operations.
// Pipe B can handle integer alu, control flow, integer multiply and divide,
// and floating point computation.
// The V pipeline is modeled by the VCQ, VA, VL, and VS resources.
let SchedModel = CHUXIN1BModel in {
let BufferSize = 0 in {
def CHUXIN1BPipeA       : ProcResource<1>;
def CHUXIN1BPipeB       : ProcResource<1>;
def CHUXIN1BIMul        : ProcResource<1>; // Int Multiply
def CHUXIN1BIDiv        : ProcResource<1>; // Int Division
def CHUXIN1BFDiv        : ProcResource<1>; // FP Division/Sqrt
def CHUXIN1BVA          : ProcResource<1>; // Arithmetic sequencer
def CHUXIN1BVL          : ProcResource<1>; // Load sequencer
def CHUXIN1BVS          : ProcResource<1>; // Store sequencer
// The VCQ accepts instructions from the the A Pipe and holds them until the
// vector unit is ready to dequeue them. The unit dequeues up to one instruction
// per cycle, in order, as soon as the sequencer for that type of instruction is
// avaliable. This resource is meant to be used for 1 cycle by all vector
// instructions, to model that only one vector instruction may be dequed at a
// time. The actual dequeueing into the sequencer is modeled by the VA, VL, and
// VS sequencer resources below. Each of them will only accept a single
// instruction at a time and remain busy for the number of cycles associated
// with that instruction.
def CHUXIN1BVCQ         : ProcResource<1>; // Vector Command Queue
}

def CHUXIN1BPipeAB : ProcResGroup<[CHUXIN1BPipeA, CHUXIN1BPipeB]>;

class CHUXIN1BUOPWriteRes<SchedWrite write, int cycles = 16> // micro-op sequencer
    : WriteRes<write, [CHUXIN1BPipeA, CHUXIN1BPipeB, CHUXIN1BIDiv, 
                       CHUXIN1BFDiv, CHUXIN1BVA, CHUXIN1BVL, 
                       CHUXIN1BVS, CHUXIN1BVCQ]>
                       {let Latency = cycles;
                       let ReleaseAtCycles = [cycles, cycles, cycles,
                                              cycles, cycles, cycles,
                                              cycles, cycles];}
// CHUXIN-1B CSR
def : WriteRes<WriteCSR, [CHUXIN1BPipeB]>{
  let Latency = 5;
}

// CHUXIN-1B Jump and link
let Latency = 6 in {
def : WriteRes<WriteJal, [CHUXIN1BPipeB]>;
def : WriteRes<WriteJalr, [CHUXIN1BPipeB]>;
}

// CHUXIN-1B Branching
def : WriteRes<WriteJmp, [CHUXIN1BPipeB]> {
  let Latency = 1;
}

// Integer arithmetic and logic
// TODO: latency of and & andi instructions is 1, not 2
let Latency = 2 in {
def : WriteRes<WriteIALU, [CHUXIN1BPipeAB]>;
def : WriteRes<WriteIALU32, [CHUXIN1BPipeAB]>;
def : WriteRes<WriteShiftImm, [CHUXIN1BPipeAB]>;
def : WriteRes<WriteShiftImm32, [CHUXIN1BPipeAB]>;
def : WriteRes<WriteShiftReg, [CHUXIN1BPipeAB]>;
def : WriteRes<WriteShiftReg32, [CHUXIN1BPipeAB]>;
}

// CHUXIN-1B Integer multiplication

def : WriteRes<WriteIMul, [CHUXIN1BPipeB, CHUXIN1BIMul]>{
  let Latency = 8;
  let ReleaseAtCycles = [1, 7];
}
def : WriteRes<WriteIMul32, [CHUXIN1BPipeB, CHUXIN1BIMul]>{
  let Latency = 8;
  let ReleaseAtCycles = [1, 7];
}

// CHUXIN-1B Integer division
def : WriteRes<WriteIDiv, [CHUXIN1BPipeB, CHUXIN1BIDiv]> {
  let Latency = 71;
  let ReleaseAtCycles = [1, 70];
}
def : WriteRes<WriteIDiv32,  [CHUXIN1BPipeB, CHUXIN1BIDiv]> {
  let Latency = 39;
  let ReleaseAtCycles = [1, 38];
}


// Memory

let Latency = 5 in {
def : WriteRes<WriteSTB, [CHUXIN1BPipeA]>;
def : WriteRes<WriteSTH, [CHUXIN1BPipeA]>;
def : WriteRes<WriteSTW, [CHUXIN1BPipeA]>;
def : WriteRes<WriteSTD, [CHUXIN1BPipeA]>;
def : WriteRes<WriteFST32, [CHUXIN1BPipeA]>;
def : WriteRes<WriteFST64, [CHUXIN1BPipeA]>;
}

// CHUXIN-1B load
let Latency = 5 in {
def : WriteRes<WriteLDB, [CHUXIN1BPipeA]>;
def : WriteRes<WriteLDH, [CHUXIN1BPipeA]>;
def : WriteRes<WriteLDW, [CHUXIN1BPipeA]>;
def : WriteRes<WriteLDD, [CHUXIN1BPipeA]>;
}

// CHUXIN-1B floating-point load
let Latency = 5 in {
def : WriteRes<WriteFLD32, [CHUXIN1BPipeA]>;
def : WriteRes<WriteFLD64, [CHUXIN1BPipeA]>;
}

// CHUXIN-1B general floating-point
let Latency = 3 in {
def : WriteRes<WriteFCmp32, [CHUXIN1BPipeB]>;
def : WriteRes<WriteFCmp64, [CHUXIN1BPipeB]>;
}
let Latency = 6 in {
// Single precision
def : WriteRes<WriteFAdd32, [CHUXIN1BPipeB]>;
def : WriteRes<WriteFMul32, [CHUXIN1BPipeB]>;
def : WriteRes<WriteFMA32, [CHUXIN1BPipeB]>;
def : WriteRes<WriteFClass32, [CHUXIN1BPipeB]>;
def : WriteRes<WriteFSGNJ32, [CHUXIN1BPipeB]>;
// Double precision
def : WriteRes<WriteFAdd64, [CHUXIN1BPipeB]>;
def : WriteRes<WriteFMul64, [CHUXIN1BPipeB]>;
def : WriteRes<WriteFMA64, [CHUXIN1BPipeB]>;
def : WriteRes<WriteFClass64, [CHUXIN1BPipeB]>;
def : WriteRes<WriteFSGNJ64, [CHUXIN1BPipeB]>;
// Floating-point integer move
def : WriteRes<WriteFMovI32ToF32, [CHUXIN1BPipeB]>;
def : WriteRes<WriteFMovF32ToI32, [CHUXIN1BPipeB]>;
def : WriteRes<WriteFMovI64ToF64, [CHUXIN1BPipeB]>;
def : WriteRes<WriteFMovF64ToI64, [CHUXIN1BPipeB]>;
}

// CHUXIN-1B uOPS instructions.
// Floating-point division and sqrt
def : CHUXIN1BUOPWriteRes<WriteFDiv32, 52>;
def : CHUXIN1BUOPWriteRes<WriteFDiv64, 65>;
def : CHUXIN1BUOPWriteRes<WriteFSqrt32, 58>;
def : CHUXIN1BUOPWriteRes<WriteFSqrt64, 70>;
// Floating-point min and max
def : CHUXIN1BUOPWriteRes<WriteFMinMax64, 55>;
def : CHUXIN1BUOPWriteRes<WriteFMinMax32, 55>;
// Integer remainder
def : CHUXIN1BUOPWriteRes<WriteIRem, 78>;
def : CHUXIN1BUOPWriteRes<WriteIRem32, 45>;



// CHUXIN-1B Conversions
def : CHUXIN1BUOPWriteRes<WriteFCvtF32ToI32, 30>; // fcvt.w(u).s
def : CHUXIN1BUOPWriteRes<WriteFCvtF32ToI64, 30>; // fcvt.l(u).d
let Latency = 6 in {
def : WriteRes<WriteFCvtF64ToF32, [CHUXIN1BPipeB]>; // fcvt.s.d
def : WriteRes<WriteFCvtF32ToF64, [CHUXIN1BPipeB]>; // fcvt.d.s
}
def : CHUXIN1BUOPWriteRes<WriteFCvtI32ToF32, 34>; // fcvt.s.w(u)
def : CHUXIN1BUOPWriteRes<WriteFCvtI32ToF64, 34>; // fcvt.d.w(u)

def : CHUXIN1BUOPWriteRes<WriteFCvtI64ToF32, 30>; // fcvt.s.l(u)
def : CHUXIN1BUOPWriteRes<WriteFCvtI64ToF64, 30>; // fcvt.d.l(u)

def : CHUXIN1BUOPWriteRes<WriteFCvtF64ToI32, 36>; // fcvt.w(u).d
def : CHUXIN1BUOPWriteRes<WriteFCvtF64ToI64, 36>; // fcvt.l(u).d

// Atomic memory
// TODO:
def : CHUXIN1BUOPWriteRes<WriteAtomicSTW, 16>;
def : CHUXIN1BUOPWriteRes<WriteAtomicSTD, 16>;
def : CHUXIN1BUOPWriteRes<WriteAtomicW, 16>;
def : CHUXIN1BUOPWriteRes<WriteAtomicD, 16>;
def : CHUXIN1BUOPWriteRes<WriteAtomicLDW, 16>;
def : CHUXIN1BUOPWriteRes<WriteAtomicLDD, 16>;

// 6. Configuration-Setting Instructions
let Latency = 5 in {
def : WriteRes<WriteVSETVLI, [CHUXIN1BPipeA]>;
def : WriteRes<WriteVSETIVLI, [CHUXIN1BPipeA]>;
def : WriteRes<WriteVSETVL, [CHUXIN1BPipeA]>;
}

// 7. Vector Loads and Stores
// Unit-stride loads and stores can operate at the full bandwidth of the memory
// pipe. The memory pipe is DLEN bits wide on x280.
foreach mx = SchedMxList in {
  defvar Cycles = CHUXIN1BGetCyclesDefault<mx>.c;
  defvar IsWorstCase = CHUXIN1BIsWorstCaseMX<mx, SchedMxList>.c;
  let Latency = 4, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
    defm "" : LMULWriteResMX<"WriteVLDE",    [CHUXIN1BVCQ, CHUXIN1BVL], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVLDFF",   [CHUXIN1BVCQ, CHUXIN1BVL], mx, IsWorstCase>;
  }
  let Latency = 1, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in
  defm "" : LMULWriteResMX<"WriteVSTE",    [CHUXIN1BVCQ, CHUXIN1BVS], mx, IsWorstCase>;
}

foreach mx = SchedMxList in {
  defvar Cycles = CHUXIN1BGetMaskLoadStoreCycles<mx>.c;
  defvar IsWorstCase = CHUXIN1BIsWorstCaseMX<mx, SchedMxList>.c;
  let Latency = 4, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in
  defm "" : LMULWriteResMX<"WriteVLDM",    [CHUXIN1BVCQ, CHUXIN1BVL], mx, IsWorstCase>;
  let Latency = 1, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in
  defm "" : LMULWriteResMX<"WriteVSTM",    [CHUXIN1BVCQ, CHUXIN1BVS], mx, IsWorstCase>;
}

// Strided loads and stores operate at one element per cycle and should be
// scheduled accordingly. Indexed loads and stores operate at one element per
// cycle, and they stall the machine until all addresses have been generated,
// so they cannot be scheduled. Indexed and strided loads and stores have LMUL
// specific suffixes, but since SEW is already encoded in the name of the
// resource, we do not need to use LMULSEWXXX constructors. However, we do
// use the SEW from the name to determine the number of Cycles.

foreach mx = SchedMxList in {
  defvar VLDSX0Cycles = CHUXIN1BGetCyclesDefault<mx>.c;
  defvar Cycles = CHUXIN1BGetCyclesOnePerElement<mx, 8>.c;
  defvar IsWorstCase = CHUXIN1BIsWorstCaseMX<mx, SchedMxList>.c;
  defm CHUXIN1B : LMULWriteResMXVariant<"WriteVLDS8",  VLDSX0Pred, [CHUXIN1BVCQ, CHUXIN1BVL],
                                       4, [0, 1], [1, !add(1, VLDSX0Cycles)], !add(3, Cycles),
                                       [0, 1], [1, !add(1, Cycles)], mx, IsWorstCase>;
  let Latency = !add(3, Cycles), AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
    defm "" : LMULWriteResMX<"WriteVLDUX8", [CHUXIN1BVCQ, CHUXIN1BVL], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVLDOX8", [CHUXIN1BVCQ, CHUXIN1BVL], mx, IsWorstCase>;
  }
  let Latency = 1, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
    defm "" : LMULWriteResMX<"WriteVSTS8",  [CHUXIN1BVCQ, CHUXIN1BVS], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVSTUX8", [CHUXIN1BVCQ, CHUXIN1BVS], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVSTOX8", [CHUXIN1BVCQ, CHUXIN1BVS], mx, IsWorstCase>;
  }
}
// TODO: The MxLists need to be filtered by EEW. We only need to support
// LMUL >= SEW_min/ELEN. Here, the smallest EEW prevents us from having MF8
// since LMUL >= 16/64.
foreach mx = ["MF4", "MF2", "M1", "M2", "M4", "M8"] in {
  defvar VLDSX0Cycles = CHUXIN1BGetCyclesDefault<mx>.c;
  defvar Cycles = CHUXIN1BGetCyclesOnePerElement<mx, 16>.c;
  defvar IsWorstCase = CHUXIN1BIsWorstCaseMX<mx, SchedMxList>.c;
  defm CHUXIN1B : LMULWriteResMXVariant<"WriteVLDS16",  VLDSX0Pred, [CHUXIN1BVCQ, CHUXIN1BVL],
                                       4, [0, 1], [1, !add(1, VLDSX0Cycles)], !add(3, Cycles),
                                       [0, 1], [1, !add(1, Cycles)], mx, IsWorstCase>;
  let Latency = !add(3, Cycles), AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
    defm "" : LMULWriteResMX<"WriteVLDUX16", [CHUXIN1BVCQ, CHUXIN1BVL], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVLDOX16", [CHUXIN1BVCQ, CHUXIN1BVL], mx, IsWorstCase>;
  }
  let Latency = 1, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
    defm "" : LMULWriteResMX<"WriteVSTS16",  [CHUXIN1BVCQ, CHUXIN1BVS], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVSTUX16", [CHUXIN1BVCQ, CHUXIN1BVS], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVSTOX16", [CHUXIN1BVCQ, CHUXIN1BVS], mx, IsWorstCase>;
  }
}
foreach mx = ["MF2", "M1", "M2", "M4", "M8"] in {
  defvar VLDSX0Cycles = CHUXIN1BGetCyclesDefault<mx>.c;
  defvar Cycles = CHUXIN1BGetCyclesOnePerElement<mx, 32>.c;
  defvar IsWorstCase = CHUXIN1BIsWorstCaseMX<mx, SchedMxList>.c;
  defm CHUXIN1B : LMULWriteResMXVariant<"WriteVLDS32",  VLDSX0Pred, [CHUXIN1BVCQ, CHUXIN1BVL],
                                       4, [0, 1], [1, !add(1, VLDSX0Cycles)], !add(3, Cycles),
                                       [0, 1], [1, !add(1, Cycles)], mx, IsWorstCase>;
  let Latency = !add(3, Cycles), AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
    defm "" : LMULWriteResMX<"WriteVLDUX32", [CHUXIN1BVCQ, CHUXIN1BVL], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVLDOX32", [CHUXIN1BVCQ, CHUXIN1BVL], mx, IsWorstCase>;
  }
  let Latency = 1, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
    defm "" : LMULWriteResMX<"WriteVSTS32",  [CHUXIN1BVCQ, CHUXIN1BVS], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVSTUX32", [CHUXIN1BVCQ, CHUXIN1BVS], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVSTOX32", [CHUXIN1BVCQ, CHUXIN1BVS], mx, IsWorstCase>;
  }
}
foreach mx = ["M1", "M2", "M4", "M8"] in {
  defvar VLDSX0Cycles = CHUXIN1BGetCyclesDefault<mx>.c;
  defvar Cycles = CHUXIN1BGetCyclesOnePerElement<mx, 64>.c;
  defvar IsWorstCase = CHUXIN1BIsWorstCaseMX<mx, SchedMxList>.c;
  defm CHUXIN1B : LMULWriteResMXVariant<"WriteVLDS64",  VLDSX0Pred, [CHUXIN1BVCQ, CHUXIN1BVL],
                                       4, [0, 1], [1, !add(1, VLDSX0Cycles)], !add(3, Cycles),
                                       [0, 1], [1, !add(1, Cycles)], mx, IsWorstCase>;
  let Latency = !add(3, Cycles), AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
    defm "" : LMULWriteResMX<"WriteVLDUX64", [CHUXIN1BVCQ, CHUXIN1BVL], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVLDOX64", [CHUXIN1BVCQ, CHUXIN1BVL], mx, IsWorstCase>;
  }
  let Latency = 1, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
    defm "" : LMULWriteResMX<"WriteVSTS64",  [CHUXIN1BVCQ, CHUXIN1BVS], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVSTUX64", [CHUXIN1BVCQ, CHUXIN1BVS], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVSTOX64", [CHUXIN1BVCQ, CHUXIN1BVS], mx, IsWorstCase>;
  }
}

// VLD*R is LMUL aware
let Latency = 4, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, 2)] in
  def : WriteRes<WriteVLD1R,  [CHUXIN1BVCQ, CHUXIN1BVL]>;
let Latency = 4, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, 4)] in
  def : WriteRes<WriteVLD2R,  [CHUXIN1BVCQ, CHUXIN1BVL]>;
let Latency = 4, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, 8)] in
  def : WriteRes<WriteVLD4R,  [CHUXIN1BVCQ, CHUXIN1BVL]>;
let Latency = 4, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, 16)] in
  def : WriteRes<WriteVLD8R,  [CHUXIN1BVCQ, CHUXIN1BVL]>;
// VST*R is LMUL aware
let Latency = 1, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, 2)] in
  def : WriteRes<WriteVST1R,   [CHUXIN1BVCQ, CHUXIN1BVS]>;
let Latency = 1, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, 4)] in
  def : WriteRes<WriteVST2R,   [CHUXIN1BVCQ, CHUXIN1BVS]>;
let Latency = 1, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, 8)] in
  def : WriteRes<WriteVST4R,   [CHUXIN1BVCQ, CHUXIN1BVS]>;
let Latency = 1, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, 16)] in
  def : WriteRes<WriteVST8R,   [CHUXIN1BVCQ, CHUXIN1BVS]>;

// Segmented Loads and Stores
// Unit-stride segmented loads and stores are effectively converted into strided
// segment loads and stores. Strided segment loads and stores operate at up to
// one segment per cycle if the segment fits within one aligned memory beat.
// Indexed segment loads and stores operate at the same rate as strided ones,
// but they stall the machine until all addresses have been generated.
foreach mx = SchedMxList in {
  foreach eew = [8, 16, 32, 64] in {
    defvar Cycles = CHUXIN1BGetCyclesSegmentedSeg2<mx>.c;
    defvar IsWorstCase = CHUXIN1BIsWorstCaseMX<mx, SchedMxList>.c;
    // Does not chain so set latency high
    let Latency = !add(3, Cycles), AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
      defm "" : LMULWriteResMX<"WriteVLSEG2e" # eew,   [CHUXIN1BVCQ, CHUXIN1BVL], mx, IsWorstCase>;
      defm "" : LMULWriteResMX<"WriteVLSEGFF2e" # eew, [CHUXIN1BVCQ, CHUXIN1BVL], mx, IsWorstCase>;
    }
    let Latency = 1, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in
    defm "" : LMULWriteResMX<"WriteVSSEG2e" # eew,   [CHUXIN1BVCQ, CHUXIN1BVS], mx, IsWorstCase>;
    foreach nf=3-8 in {
      defvar Cycles = CHUXIN1BGetCyclesSegmented<mx, eew, nf>.c;
      defvar IsWorstCase = CHUXIN1BIsWorstCaseMX<mx, SchedMxList>.c;
      // Does not chain so set latency high
      let Latency = !add(3, Cycles), AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
        defm "" : LMULWriteResMX<"WriteVLSEG" # nf # "e" # eew,   [CHUXIN1BVCQ, CHUXIN1BVL], mx, IsWorstCase>;
        defm "" : LMULWriteResMX<"WriteVLSEGFF" # nf # "e" # eew, [CHUXIN1BVCQ, CHUXIN1BVL], mx, IsWorstCase>;
      }
      let Latency = 1, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in
      defm "" : LMULWriteResMX<"WriteVSSEG" # nf # "e" # eew,   [CHUXIN1BVCQ, CHUXIN1BVS], mx, IsWorstCase>;
    }
  }
}
foreach mx = SchedMxList in {
  foreach nf=2-8 in {
    foreach eew = [8, 16, 32, 64] in {
      defvar Cycles = CHUXIN1BGetCyclesSegmented<mx, eew, nf>.c;
      defvar IsWorstCase = CHUXIN1BIsWorstCaseMX<mx, SchedMxList>.c;
      // Does not chain so set latency high
      let Latency = !add(3, Cycles), AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
        defm "" : LMULWriteResMX<"WriteVLSSEG" # nf # "e" # eew,  [CHUXIN1BVCQ, CHUXIN1BVL], mx, IsWorstCase>;
        defm "" : LMULWriteResMX<"WriteVLUXSEG" # nf # "e" # eew, [CHUXIN1BVCQ, CHUXIN1BVL], mx, IsWorstCase>;
        defm "" : LMULWriteResMX<"WriteVLOXSEG" # nf # "e" # eew, [CHUXIN1BVCQ, CHUXIN1BVL], mx, IsWorstCase>;
      }
      let Latency = 1, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
        defm "" : LMULWriteResMX<"WriteVSSSEG" # nf # "e" # eew,  [CHUXIN1BVCQ, CHUXIN1BVS], mx, IsWorstCase>;
        defm "" : LMULWriteResMX<"WriteVSUXSEG" # nf # "e" # eew, [CHUXIN1BVCQ, CHUXIN1BVS], mx, IsWorstCase>;
        defm "" : LMULWriteResMX<"WriteVSOXSEG" # nf # "e" # eew, [CHUXIN1BVCQ, CHUXIN1BVS], mx, IsWorstCase>;
      }
    }
  }
}

// 11. Vector Integer Arithmetic Instructions
foreach mx = SchedMxList in {
  defvar Cycles = CHUXIN1BGetCyclesDefault<mx>.c;
  defvar IsWorstCase = CHUXIN1BIsWorstCaseMX<mx, SchedMxList>.c;
  let Latency = 4, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
    defm "" : LMULWriteResMX<"WriteVIALUV",     [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVIALUX",     [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVIALUI",     [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVICALUV",    [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVICALUX",    [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVICALUI",    [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVShiftV",    [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVShiftX",    [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVShiftI",    [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVIMinMaxV",  [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVIMinMaxX",  [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVIMulV",     [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVIMulX",     [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVIMulAddV",  [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVIMulAddX",  [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVIMergeV",   [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVIMergeX",   [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVIMergeI",   [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVIMovV",     [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVIMovX",     [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVIMovI",     [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
  }
  // Mask results can't chain.
  let Latency = !add(Cycles, 3), AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
    defm "" : LMULWriteResMX<"WriteVICmpV",     [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVICmpX",     [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVICmpI",     [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
  }
}
foreach mx = SchedMxList in {
  defvar Cycles = CHUXIN1BGetCyclesDefault<mx>.c;
  defvar IsWorstCase = CHUXIN1BIsWorstCaseMX<mx, SchedMxList>.c;
  let Latency = 4, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
    defm "" : LMULWriteResMX<"WriteVExtV",      [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
  }
}
foreach mx = SchedMxList in {
  foreach sew = SchedSEWSet<mx>.val in {
    defvar Cycles = !mul(CHUXIN1BGetDivOrSqrtFactor<sew>.c,
                         !div(CHUXIN1BGetCyclesOnePerElement<mx, sew>.c, 4));
    defvar IsWorstCase = CHUXIN1BIsWorstCaseMXSEW<mx, sew, SchedMxList>.c;
    let Latency = Cycles, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
      defm "" : LMULSEWWriteResMXSEW<"WriteVIDivV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
      defm "" : LMULSEWWriteResMXSEW<"WriteVIDivX", [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
    }
  }
}

// Widening
foreach mx = SchedMxListW in {
  defvar Cycles = CHUXIN1BGetCyclesDefault<mx>.c;
  defvar IsWorstCase = CHUXIN1BIsWorstCaseMX<mx, SchedMxListW>.c;
  let Latency = 8, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
    defm "" : LMULWriteResMX<"WriteVIWALUV",    [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVIWALUX",    [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVIWALUI",    [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVIWMulV",    [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVIWMulX",    [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVIWMulAddV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVIWMulAddX", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
  }
}
// Narrowing
foreach mx = SchedMxListW in {
  defvar Cycles = CHUXIN1BGetCyclesNarrowing<mx>.c;
  defvar IsWorstCase = CHUXIN1BIsWorstCaseMX<mx, SchedMxListW>.c;
  let Latency = 8, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
    defm "" : LMULWriteResMX<"WriteVNShiftV",   [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVNShiftX",   [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVNShiftI",   [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
  }
}

// 12. Vector Fixed-Point Arithmetic Instructions
foreach mx = SchedMxList in {
  defvar Cycles = CHUXIN1BGetCyclesDefault<mx>.c;
  defvar IsWorstCase = CHUXIN1BIsWorstCaseMX<mx, SchedMxList>.c;
  let Latency = 8, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
    defm "" : LMULWriteResMX<"WriteVSALUV",   [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVSALUX",   [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVSALUI",   [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVAALUV",   [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVAALUX",   [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVSMulV",   [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVSMulX",   [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVSShiftV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVSShiftX", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVSShiftI", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
  }
}
// Narrowing
foreach mx = SchedMxListW in {
  defvar Cycles = CHUXIN1BGetCyclesNarrowing<mx>.c;
  defvar IsWorstCase = CHUXIN1BIsWorstCaseMX<mx, SchedMxListW>.c;
  let Latency = 8, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
    defm "" : LMULWriteResMX<"WriteVNClipV",  [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVNClipX",  [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVNClipI",  [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
  }
}

// 13. Vector Floating-Point Instructions
foreach mx = SchedMxListF in {
  foreach sew = SchedSEWSet<mx, isF=1>.val in {
    defvar Cycles = CHUXIN1BGetCyclesDefault<mx>.c;
    defvar IsWorstCase = CHUXIN1BIsWorstCaseMXSEW<mx, sew, SchedMxListF, isF=1>.c;
    let Latency = 8, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
      defm "" : LMULSEWWriteResMXSEW<"WriteVFALUV",  [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
      defm "" : LMULSEWWriteResMXSEW<"WriteVFALUF",  [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
      defm "" : LMULSEWWriteResMXSEW<"WriteVFMulV",  [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
      defm "" : LMULSEWWriteResMXSEW<"WriteVFMulF",  [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
      defm "" : LMULSEWWriteResMXSEW<"WriteVFMulAddV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
      defm "" : LMULSEWWriteResMXSEW<"WriteVFMulAddF", [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
      defm "" : LMULSEWWriteResMXSEW<"WriteVFRecpV",   [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
      defm "" : LMULSEWWriteResMXSEW<"WriteVFCvtIToFV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
    }
    let Latency = 4, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
      defm "" : LMULSEWWriteResMXSEW<"WriteVFMinMaxV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
      defm "" : LMULSEWWriteResMXSEW<"WriteVFMinMaxF", [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
      defm "" : LMULSEWWriteResMXSEW<"WriteVFSgnjV",   [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
      defm "" : LMULSEWWriteResMXSEW<"WriteVFSgnjF",   [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
    }
  }
}
foreach mx = SchedMxList in {
  defvar Cycles = CHUXIN1BGetCyclesDefault<mx>.c;
  defvar IsWorstCase = CHUXIN1BIsWorstCaseMX<mx, SchedMxList>.c;
  let Latency = 8, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
    defm "" : LMULWriteResMX<"WriteVFCvtFToIV",  [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
  }
  let Latency = 4, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
    defm "" : LMULWriteResMX<"WriteVFClassV",    [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVFMergeV",    [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVFMovV",      [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
  }
  // Mask results can't chain.
  let Latency = !add(Cycles, 3), AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
    defm "" : LMULWriteResMX<"WriteVFCmpV",      [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVFCmpF",      [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
  }
}
foreach mx = SchedMxListF in {
  foreach sew = SchedSEWSet<mx, isF=1>.val in {
    defvar Cycles = !mul(CHUXIN1BGetDivOrSqrtFactor<sew>.c,
                         !div(CHUXIN1BGetCyclesOnePerElement<mx, sew>.c, 4));
    defvar IsWorstCase = CHUXIN1BIsWorstCaseMXSEW<mx, sew, SchedMxListF, 1>.c;
    let Latency = Cycles, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
      defm "" : LMULSEWWriteResMXSEW<"WriteVFSqrtV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
      defm "" : LMULSEWWriteResMXSEW<"WriteVFDivV",  [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
      defm "" : LMULSEWWriteResMXSEW<"WriteVFDivF",  [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
    }
  }
}

// Widening
foreach mx = SchedMxListW in {
  foreach sew = SchedSEWSet<mx, isF=0, isWidening=1>.val in {
    defvar Cycles = CHUXIN1BGetCyclesDefault<mx>.c;
    defvar IsWorstCase = CHUXIN1BIsWorstCaseMXSEW<mx, sew, SchedMxListW>.c;
    let Latency = 8, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in
    defm "" : LMULSEWWriteResMXSEW<"WriteVFWCvtIToFV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
  }
}
foreach mx = SchedMxListFW in {
  foreach sew = SchedSEWSet<mx, isF=1, isWidening=1>.val in {
    defvar Cycles = CHUXIN1BGetCyclesDefault<mx>.c;
    defvar IsWorstCase = CHUXIN1BIsWorstCaseMXSEW<mx, sew, SchedMxListFW, isF=1>.c;
    let Latency = 8, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
      defm "" : LMULSEWWriteResMXSEW<"WriteVFWALUV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
      defm "" : LMULSEWWriteResMXSEW<"WriteVFWALUF", [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
      defm "" : LMULSEWWriteResMXSEW<"WriteVFWMulV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
      defm "" : LMULSEWWriteResMXSEW<"WriteVFWMulF", [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
      defm "" : LMULSEWWriteResMXSEW<"WriteVFWMulAddV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
      defm "" : LMULSEWWriteResMXSEW<"WriteVFWMulAddF", [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
      defm "" : LMULSEWWriteResMXSEW<"WriteVFWCvtFToFV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
    }
  }
  defvar Cycles = CHUXIN1BGetCyclesDefault<mx>.c;
  defvar IsWorstCase = CHUXIN1BIsWorstCaseMX<mx, SchedMxListFW>.c;
  let Latency = 8, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in
  defm "" : LMULWriteResMX<"WriteVFWCvtFToIV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
}
// Narrowing
foreach mx = SchedMxListW in {
  defvar Cycles = CHUXIN1BGetCyclesNarrowing<mx>.c;
  defvar IsWorstCase = CHUXIN1BIsWorstCaseMX<mx, SchedMxListW>.c;
  let Latency = 8, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
    defm "" : LMULWriteResMX<"WriteVFNCvtFToIV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
  }
}
foreach mx = SchedMxListFW in {
  foreach sew = SchedSEWSet<mx, isF=1, isWidening=1>.val in {
    defvar Cycles = CHUXIN1BGetCyclesNarrowing<mx>.c;
    defvar IsWorstCase = CHUXIN1BIsWorstCaseMXSEW<mx, sew, SchedMxListFW, isF=1>.c;
    let Latency = 8, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
      defm "" : LMULSEWWriteResMXSEW<"WriteVFNCvtIToFV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
      defm "" : LMULSEWWriteResMXSEW<"WriteVFNCvtFToFV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
    }
  }
}

// 14. Vector Reduction Operations
foreach mx = SchedMxList in {
  foreach sew = SchedSEWSet<mx>.val in {
    defvar Cycles = CHUXIN1BGetReductionCycles<mx, sew>.c;
    defvar IsWorstCase = CHUXIN1BIsWorstCaseMXSEW<mx, sew, SchedMxList>.c;
    let Latency = Cycles, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
      defm "" : LMULSEWWriteResMXSEW<"WriteVIRedV_From", [CHUXIN1BVCQ, CHUXIN1BVA],
                                     mx, sew, IsWorstCase>;
      defm "" : LMULSEWWriteResMXSEW<"WriteVIRedMinMaxV_From", [CHUXIN1BVCQ, CHUXIN1BVA],
                                     mx, sew, IsWorstCase>;
    }
  }
}

foreach mx = SchedMxListWRed in {
  foreach sew = SchedSEWSet<mx, 0, 1>.val in {
    defvar Cycles = CHUXIN1BGetReductionCycles<mx, sew>.c;
    defvar IsWorstCase = CHUXIN1BIsWorstCaseMXSEW<mx, sew, SchedMxListWRed>.c;
    let Latency = Cycles, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in
    defm "" : LMULSEWWriteResMXSEW<"WriteVIWRedV_From", [CHUXIN1BVCQ, CHUXIN1BVA],
                                   mx, sew, IsWorstCase>;
  }
}

foreach mx = SchedMxListF in {
  foreach sew = SchedSEWSet<mx, 1>.val in {
    defvar RedCycles = CHUXIN1BGetReductionCycles<mx, sew>.c;
    defvar IsWorstCase = CHUXIN1BIsWorstCaseMXSEW<mx, sew, SchedMxListF, 1>.c;
    let Latency = RedCycles, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, RedCycles)] in {
      defm "" : LMULSEWWriteResMXSEW<"WriteVFRedV_From", [CHUXIN1BVCQ, CHUXIN1BVA],
                                     mx, sew, IsWorstCase>;
      defm "" : LMULSEWWriteResMXSEW<"WriteVFRedMinMaxV_From", [CHUXIN1BVCQ, CHUXIN1BVA],
                                     mx, sew, IsWorstCase>;
    }
    defvar OrdRedCycles = CHUXIN1BGetOrderedReductionCycles<mx, sew>.c;
    let Latency = OrdRedCycles, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, OrdRedCycles)] in
    defm "" : LMULSEWWriteResMXSEW<"WriteVFRedOV_From", [CHUXIN1BVCQ, CHUXIN1BVA],
                                   mx, sew, IsWorstCase>;
  }
}

foreach mx = SchedMxListFWRed in {
  foreach sew = SchedSEWSet<mx, 1, 1>.val in {
    defvar RedCycles = CHUXIN1BGetReductionCycles<mx, sew>.c;
    defvar IsWorstCase = CHUXIN1BIsWorstCaseMXSEW<mx, sew, SchedMxListFWRed, 1>.c;
    let Latency = RedCycles, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, RedCycles)] in
    defm "" : LMULSEWWriteResMXSEW<"WriteVFWRedV_From", [CHUXIN1BVCQ, CHUXIN1BVA],
                                   mx, sew, IsWorstCase>;
    defvar OrdRedCycles = CHUXIN1BGetOrderedReductionCycles<mx, sew>.c;
    let Latency = OrdRedCycles, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, OrdRedCycles)] in
    defm "" : LMULSEWWriteResMXSEW<"WriteVFWRedOV_From", [CHUXIN1BVCQ, CHUXIN1BVA],
                                   mx, sew, IsWorstCase>;
  }
}

// 15. Vector Mask Instructions
foreach mx = SchedMxList in {
  defvar Cycles = CHUXIN1BGetCyclesVMask<mx>.c;
  defvar IsWorstCase = CHUXIN1BIsWorstCaseMX<mx, SchedMxList>.c;
  let Latency = 4, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
    defm "" : LMULWriteResMX<"WriteVMALUV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVMPopV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVMFFSV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVMSFSV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
  }
}
foreach mx = SchedMxList in {
  defvar Cycles = CHUXIN1BGetCyclesDefault<mx>.c;
  defvar IsWorstCase = CHUXIN1BIsWorstCaseMX<mx, SchedMxList>.c;
  let Latency = 4, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
    defm "" : LMULWriteResMX<"WriteVIotaV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVIdxV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
  }
}

// 16. Vector Permutation Instructions
let Latency = 4, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, 1)] in {
  def : WriteRes<WriteVMovSX, [CHUXIN1BVCQ, CHUXIN1BVA]>;
  def : WriteRes<WriteVMovXS, [CHUXIN1BVCQ, CHUXIN1BVA]>;
  def : WriteRes<WriteVMovSF, [CHUXIN1BVCQ, CHUXIN1BVA]>;
  def : WriteRes<WriteVMovFS, [CHUXIN1BVCQ, CHUXIN1BVA]>;
}
foreach mx = SchedMxList in {
  defvar Cycles = CHUXIN1BGetCyclesDefault<mx>.c;
  defvar IsWorstCase = CHUXIN1BIsWorstCaseMX<mx, SchedMxList>.c;
  let Latency = 8, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
    defm "" : LMULWriteResMX<"WriteVRGatherVX",    [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVRGatherVI",    [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
  }
}

foreach mx = SchedMxList in {
  foreach sew = SchedSEWSet<mx>.val in {
    defvar Cycles = CHUXIN1BGetCyclesOnePerElement<mx, sew>.c;
    defvar IsWorstCase = CHUXIN1BIsWorstCaseMXSEW<mx, sew, SchedMxList>.c;
    let Latency = !add(Cycles, 3), AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
      defm "" : LMULSEWWriteResMXSEW<"WriteVRGatherVV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
      defm "" : LMULSEWWriteResMXSEW<"WriteVRGatherEI16VV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
      defm "" : LMULSEWWriteResMXSEW<"WriteVCompressV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, sew, IsWorstCase>;
    }
  }
}

foreach mx = SchedMxList in {
  defvar Cycles = CHUXIN1BGetCyclesDefault<mx>.c;
  defvar IsWorstCase = CHUXIN1BIsWorstCaseMX<mx, SchedMxList>.c;
  let Latency = 4, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, Cycles)] in {
    defm "" : LMULWriteResMX<"WriteVSlideUpX",   [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVSlideDownX", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVSlideI",     [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVISlide1X",   [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVFSlide1F",   [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
  }
}

// VMov*V is LMUL Aware
let Latency = 4, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, 2)] in
  def : WriteRes<WriteVMov1V,     [CHUXIN1BVCQ, CHUXIN1BVA]>;
let Latency = 4, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, 4)] in
  def : WriteRes<WriteVMov2V,     [CHUXIN1BVCQ, CHUXIN1BVA]>;
let Latency = 4, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, 8)] in
  def : WriteRes<WriteVMov4V,     [CHUXIN1BVCQ, CHUXIN1BVA]>;
let Latency = 4, AcquireAtCycles = [0, 1], ReleaseAtCycles = [1, !add(1, 16)] in
  def : WriteRes<WriteVMov8V,     [CHUXIN1BVCQ, CHUXIN1BVA]>;

// Others
//Short forward branch
def : WriteRes<WriteNop, []>;
let Latency = 3 in
  def : WriteRes<WriteRdVLENB, [CHUXIN1BPipeB]>;

def : InstRW<[WriteIALU], (instrs COPY)>;

// VCIX
//
// In principle we don't know the latency of any VCIX instructions (they
// depends on a particular coprocessor implementation). However, the default
// latency of 1 can lead to issues [1]. So instead we set the latency to the
// default provided by `CHUXIN1BGetCyclesDefault`. This is still not accurate
// and can lead to suboptimal codegen, but should hopefully be a better
// starting point.
//
// [1] https://github.com/llvm/llvm-project/issues/83391
foreach mx = SchedMxList in {
  defvar Cycles = CHUXIN1BGetCyclesDefault<mx>.c;
  defvar IsWorstCase = CHUXIN1BIsWorstCaseMX<mx, SchedMxList>.c;
  let Latency = Cycles,
      AcquireAtCycles = [0, 1],
      ReleaseAtCycles = [1, !add(1, Cycles)] in {
    defm "" : LMULWriteResMX<"WriteVC_V_I",   [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVC_V_X",   [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVC_V_IV",  [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVC_V_VV",  [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVC_V_XV",  [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVC_V_IVV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVC_V_IVW", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVC_V_VVV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVC_V_VVW", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVC_V_XVV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVC_V_XVW", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    foreach f = ["FPR16", "FPR32", "FPR64"] in {
      defm "" : LMULWriteResMX<"WriteVC_V_" # f # "V",  [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
      defm "" : LMULWriteResMX<"WriteVC_V_" # f # "VV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
      defm "" : LMULWriteResMX<"WriteVC_V_" # f # "VW", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    }
    defm "" : LMULWriteResMX<"WriteVC_I",   [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVC_X",   [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVC_IV",  [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVC_VV",  [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVC_XV",  [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVC_IVV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVC_IVW", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVC_VVV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVC_VVW", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVC_XVV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    defm "" : LMULWriteResMX<"WriteVC_XVW", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    foreach f = ["FPR16", "FPR32", "FPR64"] in {
      defm "" : LMULWriteResMX<"WriteVC_" # f # "V",  [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
      defm "" : LMULWriteResMX<"WriteVC_" # f # "VV", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
      defm "" : LMULWriteResMX<"WriteVC_" # f # "VW", [CHUXIN1BVCQ, CHUXIN1BVA], mx, IsWorstCase>;
    }
  }
}

//===----------------------------------------------------------------------===//

// Bypass and advance
def : CHUXIN1BAnyToGPRBypass<ReadJmp>;
def : CHUXIN1BAnyToGPRBypass<ReadJalr>;
def : ReadAdvance<ReadCSR, 0>;
def : CHUXIN1BAnyToGPRBypass<ReadStoreData>;
def : ReadAdvance<ReadMemBase, 0>;
def : ReadAdvance<ReadIALU, 0>;
def : ReadAdvance<ReadIALU32, 0>;
def : ReadAdvance<ReadShiftImm, 0>;
def : ReadAdvance<ReadShiftImm32, 0>;
def : ReadAdvance<ReadShiftReg, 0>;
def : ReadAdvance<ReadShiftReg32, 0>;
// def : CHUXIN1BAnyToGPRBypass<ReadIALU>;
// def : CHUXIN1BAnyToGPRBypass<ReadIALU32>;
// def : CHUXIN1BAnyToGPRBypass<ReadShiftImm>;
// def : CHUXIN1BAnyToGPRBypass<ReadShiftImm32>;
// def : CHUXIN1BAnyToGPRBypass<ReadShiftReg>;
// def : CHUXIN1BAnyToGPRBypass<ReadShiftReg32>;
def : ReadAdvance<ReadIDiv, 0>;
def : ReadAdvance<ReadIDiv32, 0>;
def : ReadAdvance<ReadIRem, 0>;
def : ReadAdvance<ReadIRem32, 0>;
def : ReadAdvance<ReadIMul, 0>;
def : ReadAdvance<ReadIMul32, 0>;
def : ReadAdvance<ReadAtomicWA, 0>;
def : ReadAdvance<ReadAtomicWD, 0>;
def : ReadAdvance<ReadAtomicDA, 0>;
def : ReadAdvance<ReadAtomicDD, 0>;
def : ReadAdvance<ReadAtomicLDW, 0>;
def : ReadAdvance<ReadAtomicLDD, 0>;
def : ReadAdvance<ReadAtomicSTW, 0>;
def : ReadAdvance<ReadAtomicSTD, 0>;
def : ReadAdvance<ReadFStoreData, 0>;
def : ReadAdvance<ReadFMemBase, 0>;
def : ReadAdvance<ReadFAdd32, 0>;
def : ReadAdvance<ReadFAdd64, 0>;
def : ReadAdvance<ReadFMul32, 0>;
def : ReadAdvance<ReadFMul64, 0>;
def : ReadAdvance<ReadFMA32, 0>;
def : ReadAdvance<ReadFMA32Addend, 0>;
def : ReadAdvance<ReadFMA64, 0>;
def : ReadAdvance<ReadFMA64Addend, 0>;
def : ReadAdvance<ReadFDiv32, 0>;
def : ReadAdvance<ReadFDiv64, 0>;
def : ReadAdvance<ReadFSqrt32, 0>;
def : ReadAdvance<ReadFSqrt64, 0>;
def : ReadAdvance<ReadFCmp32, 0>;
def : ReadAdvance<ReadFCmp64, 0>;
def : ReadAdvance<ReadFSGNJ32, 0>;
def : ReadAdvance<ReadFSGNJ64, 0>;
def : ReadAdvance<ReadFMinMax32, 0>;
def : ReadAdvance<ReadFMinMax64, 0>;
def : ReadAdvance<ReadFCvtF32ToI32, 0>;
def : ReadAdvance<ReadFCvtF32ToI64, 0>;
def : ReadAdvance<ReadFCvtF64ToI32, 0>;
def : ReadAdvance<ReadFCvtF64ToI64, 0>;
def : ReadAdvance<ReadFCvtI32ToF32, 0>;
def : ReadAdvance<ReadFCvtI32ToF64, 0>;
def : ReadAdvance<ReadFCvtI64ToF32, 0>;
def : ReadAdvance<ReadFCvtI64ToF64, 0>;
def : ReadAdvance<ReadFCvtF32ToF64, 0>;
def : ReadAdvance<ReadFCvtF64ToF32, 0>;
def : ReadAdvance<ReadFMovF32ToI32, 0>;
def : ReadAdvance<ReadFMovI32ToF32, 0>;
def : ReadAdvance<ReadFMovF64ToI64, 0>;
def : ReadAdvance<ReadFMovI64ToF64, 0>;
def : ReadAdvance<ReadFClass32, 0>;
def : ReadAdvance<ReadFClass64, 0>;

// 6. Configuration-Setting Instructions
def : ReadAdvance<ReadVSETVLI, 2>;
def : ReadAdvance<ReadVSETVL, 2>;

// 7. Vector Loads and Stores
def : ReadAdvance<ReadVLDX, 0>;
def : ReadAdvance<ReadVSTX, 0>;
defm "" : LMULReadAdvance<"ReadVSTEV", 0>;
defm "" : LMULReadAdvance<"ReadVSTM", 0>;
def : ReadAdvance<ReadVLDSX, 0>;
def : ReadAdvance<ReadVSTSX, 0>;
defm "" : LMULReadAdvance<"ReadVSTS8V", 0>;
defm "" : LMULReadAdvance<"ReadVSTS16V", 0>;
defm "" : LMULReadAdvance<"ReadVSTS32V", 0>;
defm "" : LMULReadAdvance<"ReadVSTS64V", 0>;
defm "" : LMULReadAdvance<"ReadVLDUXV", 0>;
defm "" : LMULReadAdvance<"ReadVLDOXV", 0>;
defm "" : LMULReadAdvance<"ReadVSTUX8", 0>;
defm "" : LMULReadAdvance<"ReadVSTUX16", 0>;
defm "" : LMULReadAdvance<"ReadVSTUX32", 0>;
defm "" : LMULReadAdvance<"ReadVSTUX64", 0>;
defm "" : LMULReadAdvance<"ReadVSTUXV", 0>;
defm "" : LMULReadAdvance<"ReadVSTUX8V", 0>;
defm "" : LMULReadAdvance<"ReadVSTUX16V", 0>;
defm "" : LMULReadAdvance<"ReadVSTUX32V", 0>;
defm "" : LMULReadAdvance<"ReadVSTUX64V", 0>;
defm "" : LMULReadAdvance<"ReadVSTOX8", 0>;
defm "" : LMULReadAdvance<"ReadVSTOX16", 0>;
defm "" : LMULReadAdvance<"ReadVSTOX32", 0>;
defm "" : LMULReadAdvance<"ReadVSTOX64", 0>;
defm "" : LMULReadAdvance<"ReadVSTOXV", 0>;
defm "" : LMULReadAdvance<"ReadVSTOX8V", 0>;
defm "" : LMULReadAdvance<"ReadVSTOX16V", 0>;
defm "" : LMULReadAdvance<"ReadVSTOX32V", 0>;
defm "" : LMULReadAdvance<"ReadVSTOX64V", 0>;
// LMUL Aware
def : ReadAdvance<ReadVST1R, 0>;
def : ReadAdvance<ReadVST2R, 0>;
def : ReadAdvance<ReadVST4R, 0>;
def : ReadAdvance<ReadVST8R, 0>;

// 12. Vector Integer Arithmetic Instructions
defm : LMULReadAdvance<"ReadVIALUV", 0>;
defm : LMULReadAdvance<"ReadVIALUX", 0>;
defm : LMULReadAdvanceW<"ReadVIWALUV", 0>;
defm : LMULReadAdvanceW<"ReadVIWALUX", 0>;
defm : LMULReadAdvance<"ReadVExtV", 0>;
defm : LMULReadAdvance<"ReadVICALUV", 0>;
defm : LMULReadAdvance<"ReadVICALUX", 0>;
defm : LMULReadAdvance<"ReadVShiftV", 0>;
defm : LMULReadAdvance<"ReadVShiftX", 0>;
defm : LMULReadAdvanceW<"ReadVNShiftV", 0>;
defm : LMULReadAdvanceW<"ReadVNShiftX", 0>;
defm : LMULReadAdvance<"ReadVICmpV", 0>;
defm : LMULReadAdvance<"ReadVICmpX", 0>;
defm : LMULReadAdvance<"ReadVIMinMaxV", 0>;
defm : LMULReadAdvance<"ReadVIMinMaxX", 0>;
defm : LMULReadAdvance<"ReadVIMulV", 0>;
defm : LMULReadAdvance<"ReadVIMulX", 0>;
defm : LMULSEWReadAdvance<"ReadVIDivV", 0>;
defm : LMULSEWReadAdvance<"ReadVIDivX", 0>;
defm : LMULReadAdvanceW<"ReadVIWMulV", 0>;
defm : LMULReadAdvanceW<"ReadVIWMulX", 0>;
defm : LMULReadAdvance<"ReadVIMulAddV", 0>;
defm : LMULReadAdvance<"ReadVIMulAddX", 0>;
defm : LMULReadAdvanceW<"ReadVIWMulAddV", 0>;
defm : LMULReadAdvanceW<"ReadVIWMulAddX", 0>;
defm : LMULReadAdvance<"ReadVIMergeV", 0>;
defm : LMULReadAdvance<"ReadVIMergeX", 0>;
defm : LMULReadAdvance<"ReadVIMovV", 0>;
defm : LMULReadAdvance<"ReadVIMovX", 0>;

// 13. Vector Fixed-Point Arithmetic Instructions
defm "" : LMULReadAdvance<"ReadVSALUV", 0>;
defm "" : LMULReadAdvance<"ReadVSALUX", 0>;
defm "" : LMULReadAdvance<"ReadVAALUV", 0>;
defm "" : LMULReadAdvance<"ReadVAALUX", 0>;
defm "" : LMULReadAdvance<"ReadVSMulV", 0>;
defm "" : LMULReadAdvance<"ReadVSMulX", 0>;
defm "" : LMULReadAdvance<"ReadVSShiftV", 0>;
defm "" : LMULReadAdvance<"ReadVSShiftX", 0>;
defm "" : LMULReadAdvanceW<"ReadVNClipV", 0>;
defm "" : LMULReadAdvanceW<"ReadVNClipX", 0>;

// 14. Vector Floating-Point Instructions
defm "" : LMULSEWReadAdvanceF<"ReadVFALUV", 0>;
defm "" : LMULSEWReadAdvanceF<"ReadVFALUF", 0>;
defm "" : LMULSEWReadAdvanceFW<"ReadVFWALUV", 0>;
defm "" : LMULSEWReadAdvanceFW<"ReadVFWALUF", 0>;
defm "" : LMULSEWReadAdvanceF<"ReadVFMulV", 0>;
defm "" : LMULSEWReadAdvanceF<"ReadVFMulF", 0>;
defm "" : LMULSEWReadAdvanceF<"ReadVFDivV", 0>;
defm "" : LMULSEWReadAdvanceF<"ReadVFDivF", 0>;
defm "" : LMULSEWReadAdvanceFW<"ReadVFWMulV", 0>;
defm "" : LMULSEWReadAdvanceFW<"ReadVFWMulF", 0>;
defm "" : LMULSEWReadAdvanceF<"ReadVFMulAddV", 0>;
defm "" : LMULSEWReadAdvanceF<"ReadVFMulAddF", 0>;
defm "" : LMULSEWReadAdvanceFW<"ReadVFWMulAddV", 0>;
defm "" : LMULSEWReadAdvanceFW<"ReadVFWMulAddF", 0>;
defm "" : LMULSEWReadAdvanceF<"ReadVFSqrtV", 0>;
defm "" : LMULSEWReadAdvanceF<"ReadVFRecpV", 0>;
defm "" : LMULSEWReadAdvanceF<"ReadVFMinMaxV", 0>;
defm "" : LMULSEWReadAdvanceF<"ReadVFMinMaxF", 0>;
defm "" : LMULSEWReadAdvanceF<"ReadVFSgnjV", 0>;
defm "" : LMULSEWReadAdvanceF<"ReadVFSgnjF", 0>;
defm "" : LMULReadAdvance<"ReadVFCmpV", 0>;
defm "" : LMULReadAdvance<"ReadVFCmpF", 0>;
defm "" : LMULReadAdvance<"ReadVFClassV", 0>;
defm "" : LMULReadAdvance<"ReadVFMergeV", 0>;
defm "" : LMULReadAdvance<"ReadVFMergeF", 0>;
defm "" : LMULReadAdvance<"ReadVFMovF", 0>;
defm "" : LMULSEWReadAdvanceF<"ReadVFCvtIToFV", 0>;
defm "" : LMULReadAdvance<"ReadVFCvtFToIV", 0>;
defm "" : LMULSEWReadAdvanceW<"ReadVFWCvtIToFV", 0>;
defm "" : LMULReadAdvanceFW<"ReadVFWCvtFToIV", 0>;
defm "" : LMULSEWReadAdvanceFW<"ReadVFWCvtFToFV", 0>;
defm "" : LMULSEWReadAdvanceFW<"ReadVFNCvtIToFV", 0>;
defm "" : LMULReadAdvanceW<"ReadVFNCvtFToIV", 0>;
defm "" : LMULSEWReadAdvanceFW<"ReadVFNCvtFToFV", 0>;

// 15. Vector Reduction Operations
def : ReadAdvance<ReadVIRedV, 0>;
def : ReadAdvance<ReadVIRedV0, 0>;
def : ReadAdvance<ReadVIWRedV, 0>;
def : ReadAdvance<ReadVIWRedV0, 0>;
def : ReadAdvance<ReadVFRedV, 0>;
def : ReadAdvance<ReadVFRedV0, 0>;
def : ReadAdvance<ReadVFRedOV, 0>;
def : ReadAdvance<ReadVFRedOV0, 0>;
def : ReadAdvance<ReadVFWRedV, 0>;
def : ReadAdvance<ReadVFWRedV0, 0>;
def : ReadAdvance<ReadVFWRedOV, 0>;
def : ReadAdvance<ReadVFWRedOV0, 0>;

// 16. Vector Mask Instructions
defm "" : LMULReadAdvance<"ReadVMALUV", 0>;
defm "" : LMULReadAdvance<"ReadVMPopV", 0>;
defm "" : LMULReadAdvance<"ReadVMFFSV", 0>;
defm "" : LMULReadAdvance<"ReadVMSFSV", 0>;
defm "" : LMULReadAdvance<"ReadVIotaV", 0>;

// 17. Vector Permutation Instructions
def : ReadAdvance<ReadVMovXS, 0>;
def : ReadAdvance<ReadVMovSX_V, 0>;
def : ReadAdvance<ReadVMovSX_X, 0>;
def : ReadAdvance<ReadVMovFS, 0>;
def : ReadAdvance<ReadVMovSF_V, 0>;
def : ReadAdvance<ReadVMovSF_F, 0>;
defm "" : LMULReadAdvance<"ReadVISlideV", 0>;
defm "" : LMULReadAdvance<"ReadVISlideX", 0>;
defm "" : LMULReadAdvance<"ReadVFSlideV", 0>;
defm "" : LMULReadAdvance<"ReadVFSlideF", 0>;
defm "" : LMULSEWReadAdvance<"ReadVRGatherVV_data", 0>;
defm "" : LMULSEWReadAdvance<"ReadVRGatherVV_index", 0>;
defm "" : LMULSEWReadAdvance<"ReadVRGatherEI16VV_data", 0>;
defm "" : LMULSEWReadAdvance<"ReadVRGatherEI16VV_index", 0>;
defm "" : LMULReadAdvance<"ReadVRGatherVX_data", 0>;
defm "" : LMULReadAdvance<"ReadVRGatherVX_index", 0>;
defm "" : LMULReadAdvance<"ReadVRGatherVI_data", 0>;
defm "" : LMULSEWReadAdvance<"ReadVCompressV", 0>;
// LMUL Aware
def : ReadAdvance<ReadVMov1V, 0>;
def : ReadAdvance<ReadVMov2V, 0>;
def : ReadAdvance<ReadVMov4V, 0>;
def : ReadAdvance<ReadVMov8V, 0>;

// Others
def : ReadAdvance<ReadVMask, 0>;
def : ReadAdvance<ReadVPassthru_WorstCase, 0>;
foreach mx = SchedMxList in {
  def : ReadAdvance<!cast<SchedRead>("ReadVPassthru_" # mx), 0>;
  foreach sew = SchedSEWSet<mx>.val in
    def : ReadAdvance<!cast<SchedRead>("ReadVPassthru_" # mx  # "_E" # sew), 0>;
}

//===----------------------------------------------------------------------===//
// Unsupported extensions
defm : UnsupportedSchedZabha;
defm : UnsupportedSchedSFB;
defm : UnsupportedSchedZbb;
defm : UnsupportedSchedZba;
defm : UnsupportedSchedZbs;
defm : UnsupportedSchedZbc;
defm : UnsupportedSchedZbkb;
defm : UnsupportedSchedZbkx;
defm : UnsupportedSchedZfa;
defm : UnsupportedSchedZfh;
defm : UnsupportedSchedZvk;
}
