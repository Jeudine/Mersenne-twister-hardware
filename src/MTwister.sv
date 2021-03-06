//*************************************************************************
//
// Copyright 2020 by Julien Eudine. This program is free software; you can
// redistribute it and/or modify it under the terms of the BSD 3-Clause
// License
//
//*************************************************************************

module MTwister #(parameter
    N = 624, // degree of recurrence
    M = 397, // middle word
    R = 31, // separation point of one word
    A = 32'h9908B0DF, // coefficients of the rational normal form twist matrix
    U = 11, // shift size used in the tempering process
    D = 32'hFFFFFFFF, // XOR mask used in the tempering process
    S = 7, // shift size used in tempering process
    B = 32'h9D2C5680, // XOR mask used in the tempering process
    T = 15, // shift size used in tempering process
    C = 32'hEFC60000, // XOR mask used in the tempering process
    L = 18, // shift size used in tempering process
    F = 1812433253 // initialization parameter
) (
    input clk, rst, trig,
    input [31:0] seed,
    output [31:0] r_num,
    output ready,
    output last
);

localparam INDEX_WIDTH = $clog2(N);

logic [INDEX_WIDTH-1:0] index;

wire wr;
wire [31:0] Di, Do1, Do2;
wire [INDEX_WIDTH-1:0] index_gen;

Sram_dp #(N) sram (
    .clk(clk),
    .wr(wr),
    .Addr1(index),
    .Addr2(index_gen),
    .Di(Di),
    .Do1(Do1),
    .Do2(Do2)
);

// FSM

enum logic [2:0] {INIT0, INIT1, GEN0, GEN1, GEN2, EXTR0, EXTR1} state;

always_ff @(posedge clk)
if (rst)
    state <= INIT0;
else
case (state)
    INIT0: if (index == N-2)
        state <= INIT1;
    INIT1: state <= GEN0;

    GEN0: state <= GEN1;

    GEN1: state <= GEN2;

    GEN2: if (index == 0 && !wr)
        state <= EXTR0;

    EXTR0: state <= EXTR1;

    EXTR1: if (last && trig)
        state <= GEN0;

    default: ;
endcase

// Initialize and generate the values stored in the memory

logic [31:0] Di_init;

wire [31:0] x_gen;
wire [31:0] comb_gen;
logic osci_gen;
logic [31-R:0] Do1_gen;

assign wr = rst || state == INIT0 || state == INIT1 || (state == GEN2 && osci_gen) || state == EXTR0;

assign comb_gen = Do2 ^ (x_gen >> 1);
assign x_gen = {Do1_gen, Do1[R-1:0]};

assign Di = (state == INIT0 || state == INIT1) ? Di_init :
x_gen[0] ? comb_gen ^ A : comb_gen;

localparam W_INDEX_WIDTH = 32 - INDEX_WIDTH;

always_ff @(posedge clk)
if (rst)
    Di_init <= seed;
else
    Di_init <= F * (Di_init ^ (Di_init >> (30))) + {{W_INDEX_WIDTH{1'b0}}, index} + 1;

always_ff @(posedge clk)
if (wr)
    Do1_gen <= Do1[31:R];

always_ff @(posedge clk)
if (state == GEN1)
    osci_gen <= 1;
else
    osci_gen <= ~osci_gen;

// Registers used for the extraction (used to avoid latency)

logic [31:0] y;
logic trig_r;

always_ff @(posedge clk)
if (trig)
    y <= Do1;

always_ff @(posedge clk)
    trig_r <= trig;

// Combinatory logic used to extract the number

wire [31:0] y0;
wire [31:0] y1;
wire [31:0] y2;
wire [31:0] y3;

assign y0 = (trig && !trig_r) ? y ^ ((y >> U) & D) : Do1 ^ ((Do1 >> U) & D);
assign y1 = y0 ^ ((y0 << S) & B);
assign y2 = y1 ^ ((y1 << T) & C);
assign y3 = y2 ^ (y2 >> L);

// Register used to hold the random number on the output during the extraction

logic [31:0] y3_r;

always_ff @(posedge clk)
if(trig_r)
    y3_r <= y3;

assign r_num = trig_r ? y3 : y3_r;

// Handling of index

always_ff @(posedge clk)
if (rst)
    index <= 0;
else
case(state)
    INIT0: index <= index + 1;

    INIT1: index <= 0;

    GEN0: index <= 1;

    GEN1: index <= 0;

    GEN2:
    if (index == N-2 && wr)
        index <= 0;
    else if (index == 0 && !wr)
        index <= N-1;
    else if (wr)
        index <= index + 2;
    else
        index <= index - 1;

    EXTR0: index <= 0;

    EXTR1:
    if (trig)
    begin
        if (index == N-1)
            index <= 0;
        else
            index <= index + 1;
    end
    default: ;
endcase

assign index_gen = (index + M > N) ? index + M - N -1 : index + M - 1;

assign ready = state == EXTR1;

assign last = (state == EXTR1 && index == N-1);

endmodule
