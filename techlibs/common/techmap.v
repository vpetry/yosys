/*
 *  yosys -- Yosys Open SYnthesis Suite
 *
 *  Copyright (C) 2012  Clifford Wolf <clifford@clifford.at>
 *  
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *  
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *  ---
 *
 *  The internal logic cell technology mapper.
 *
 *  This verilog library contains the mapping of internal cells (e.g. $not with
 *  variable bit width) to the internal logic cells (such as the single bit $_NOT_ 
 *  gate). Usually this logic network is then mapped to the actual technology
 *  using e.g. the "abc" pass.
 *
 *  Note that this library does not map $mem cells. They must be mapped to logic
 *  and $dff cells using the "memory_map" pass first. (Or map it to custom cells,
 *  which is of course highly recommended for larger memories.)
 *
 */

`define MIN(_a, _b) ((_a) < (_b) ? (_a) : (_b))
`define MAX(_a, _b) ((_a) > (_b) ? (_a) : (_b))


// --------------------------------------------------------
// Use simplemap for trivial cell types
// --------------------------------------------------------

(* techmap_simplemap *)
(* techmap_celltype = "$not $and $or $xor $xnor" *)
module simplemap_bool_ops;
endmodule

(* techmap_simplemap *)
(* techmap_celltype = "$reduce_and $reduce_or $reduce_xor $reduce_xnor $reduce_bool" *)
module simplemap_reduce_ops;
endmodule

(* techmap_simplemap *)
(* techmap_celltype = "$logic_not $logic_and $logic_or" *)
module simplemap_logic_ops;
endmodule

(* techmap_simplemap *)
(* techmap_celltype = "$pos $slice $concat $mux" *)
module simplemap_various;
endmodule

(* techmap_simplemap *)
(* techmap_celltype = "$sr $dff $adff $dffsr $dlatch" *)
module simplemap_registers;
endmodule


// --------------------------------------------------------
// Trivial substitutions
// --------------------------------------------------------

module \$neg (A, Y);
	parameter A_SIGNED = 0;
	parameter A_WIDTH = 1;
	parameter Y_WIDTH = 1;

	input [A_WIDTH-1:0] A;
	output [Y_WIDTH-1:0] Y;

	\$sub #(
		.A_SIGNED(A_SIGNED),
		.B_SIGNED(A_SIGNED),
		.A_WIDTH(1),
		.B_WIDTH(A_WIDTH),
		.Y_WIDTH(Y_WIDTH)
	) _TECHMAP_REPLACE_ (
		.A(1'b0),
		.B(A),
		.Y(Y)
	);
endmodule

module \$ge (A, B, Y);
	parameter A_SIGNED = 0;
	parameter B_SIGNED = 0;
	parameter A_WIDTH = 1;
	parameter B_WIDTH = 1;
	parameter Y_WIDTH = 1;

	input [A_WIDTH-1:0] A;
	input [B_WIDTH-1:0] B;
	output [Y_WIDTH-1:0] Y;

	\$le #(
		.A_SIGNED(B_SIGNED),
		.B_SIGNED(A_SIGNED),
		.A_WIDTH(B_WIDTH),
		.B_WIDTH(A_WIDTH),
		.Y_WIDTH(Y_WIDTH)
	) _TECHMAP_REPLACE_ (
		.A(B),
		.B(A),
		.Y(Y)
	);
endmodule

module \$gt (A, B, Y);
	parameter A_SIGNED = 0;
	parameter B_SIGNED = 0;
	parameter A_WIDTH = 1;
	parameter B_WIDTH = 1;
	parameter Y_WIDTH = 1;

	input [A_WIDTH-1:0] A;
	input [B_WIDTH-1:0] B;
	output [Y_WIDTH-1:0] Y;

	\$lt #(
		.A_SIGNED(B_SIGNED),
		.B_SIGNED(A_SIGNED),
		.A_WIDTH(B_WIDTH),
		.B_WIDTH(A_WIDTH),
		.Y_WIDTH(Y_WIDTH)
	) _TECHMAP_REPLACE_ (
		.A(B),
		.B(A),
		.Y(Y)
	);
endmodule


// --------------------------------------------------------
// Shift operators
// --------------------------------------------------------

(* techmap_celltype = "$shr $shl $sshl $sshr" *)
module shift_ops_shr_shl_sshl_sshr (A, B, Y);
	parameter A_SIGNED = 0;
	parameter B_SIGNED = 0;
	parameter A_WIDTH = 1;
	parameter B_WIDTH = 1;
	parameter Y_WIDTH = 1;

	parameter _TECHMAP_CELLTYPE_ = "";
	localparam shift_left = _TECHMAP_CELLTYPE_ == "$shl" || _TECHMAP_CELLTYPE_ == "$sshl";
	localparam sign_extend = A_SIGNED && _TECHMAP_CELLTYPE_ == "$sshr";

	input [A_WIDTH-1:0] A;
	input [B_WIDTH-1:0] B;
	output [Y_WIDTH-1:0] Y;

	localparam WIDTH = `MAX(A_WIDTH, Y_WIDTH);
	localparam BB_WIDTH = `MIN($clog2(shift_left ? Y_WIDTH : A_SIGNED ? WIDTH : A_WIDTH) + 1, B_WIDTH);

	wire [1023:0] _TECHMAP_DO_00_ = "proc;;";
	wire [1023:0] _TECHMAP_DO_01_ = "RECURSION; CONSTMAP; opt_muxtree; opt_const -mux_undef -mux_bool -fine;;;";

	integer i;
	reg [WIDTH-1:0] buffer;
	reg overflow;

	always @* begin
		overflow = B_WIDTH > BB_WIDTH ? |B[B_WIDTH-1:BB_WIDTH] : 1'b0;
		buffer = overflow ? {WIDTH{sign_extend ? A[A_WIDTH-1] : 1'b0}} : {{WIDTH-A_WIDTH{A_SIGNED ? A[A_WIDTH-1] : 1'b0}}, A};

		for (i = 0; i < BB_WIDTH; i = i+1)
			if (B[i]) begin
				if (shift_left)
					buffer = {buffer, (2**i)'b0};
				else if (2**i < WIDTH)
					buffer = {{2**i{sign_extend ? buffer[WIDTH-1] : 1'b0}}, buffer[WIDTH-1 : 2**i]};
				else
					buffer = {WIDTH{sign_extend ? buffer[WIDTH-1] : 1'b0}};
			end
	end

	assign Y = buffer;
endmodule

(* techmap_celltype = "$shift $shiftx" *)
module shift_shiftx (A, B, Y);
	parameter A_SIGNED = 0;
	parameter B_SIGNED = 0;
	parameter A_WIDTH = 1;
	parameter B_WIDTH = 1;
	parameter Y_WIDTH = 1;

	input [A_WIDTH-1:0] A;
	input [B_WIDTH-1:0] B;
	output [Y_WIDTH-1:0] Y;

	localparam BB_WIDTH = `MIN($clog2(`MAX(A_WIDTH, Y_WIDTH)) + (B_SIGNED ? 2 : 1), B_WIDTH);
	localparam WIDTH = `MAX(A_WIDTH, Y_WIDTH) + (B_SIGNED ? 2**(BB_WIDTH-1) : 0);

	parameter _TECHMAP_CELLTYPE_ = "";
	localparam extbit = _TECHMAP_CELLTYPE_ == "$shift" ? 1'b0 : 1'bx;

	wire [1023:0] _TECHMAP_DO_00_ = "proc;;";
	wire [1023:0] _TECHMAP_DO_01_ = "CONSTMAP; opt_muxtree; opt_const -mux_undef -mux_bool -fine;;;";

	integer i;
	reg [WIDTH-1:0] buffer;
	reg overflow;

	always @* begin
		overflow = 0;
		buffer = {WIDTH{extbit}};
		buffer[`MAX(A_WIDTH, Y_WIDTH)-1:0] = A;

		if (B_WIDTH > BB_WIDTH) begin
			if (B_SIGNED) begin
				for (i = BB_WIDTH; i < B_WIDTH; i = i+1)
					if (B[i] != B[BB_WIDTH-1])
						overflow = 1;
			end else
				overflow = |B[B_WIDTH-1:BB_WIDTH];
			if (overflow)
				buffer = {WIDTH{extbit}};
		end

		for (i = BB_WIDTH-1; i >= 0; i = i-1)
			if (B[i]) begin
				if (B_SIGNED && i == BB_WIDTH-1)
					buffer = {buffer, {2**i{extbit}}};
				else if (2**i < WIDTH)
					buffer = {{2**i{extbit}}, buffer[WIDTH-1 : 2**i]};
				else
					buffer = {WIDTH{extbit}};
			end
	end

	assign Y = buffer;
endmodule


// --------------------------------------------------------
// ALU Infrastructure
// --------------------------------------------------------

module \$fa (A, B, C, X, Y);
	parameter WIDTH = 1;

	input [WIDTH-1:0] A, B, C;
	output [WIDTH-1:0] X, Y;

	wire [WIDTH-1:0] t1, t2, t3;

	assign t1 = A ^ B, t2 = A & B, t3 = C & t1;
	assign Y = t1 ^ C, X = t2 | t3;
endmodule

module \$lcu (P, G, CI, CO);
	parameter WIDTH = 2;

	input [WIDTH-1:0] P, G;
	input CI;

	output [WIDTH-1:0] CO;

	integer i, j;
	reg [WIDTH-1:0] p, g;

	wire [1023:0] _TECHMAP_DO_ = "proc; opt -fast";

	always @* begin
		p = P;
		g = G;

		// in almost all cases CI will be constant zero
		g[0] = g[0] | (p[0] & CI);

		// [[CITE]] Brent Kung Adder
		// R. P. Brent and H. T. Kung, “A Regular Layout for Parallel Adders”,
		// IEEE Transaction on Computers, Vol. C-31, No. 3, p. 260-264, March, 1982

		// Main tree
		for (i = 1; i <= $clog2(WIDTH); i = i+1) begin
			for (j = 2**i - 1; j < WIDTH; j = j + 2**i) begin
				g[j] = g[j] | p[j] & g[j - 2**(i-1)];
				p[j] = p[j] & p[j - 2**(i-1)];
			end
		end

		// Inverse tree
		for (i = $clog2(WIDTH); i > 0; i = i-1) begin
			for (j = 2**i + 2**(i-1) - 1; j < WIDTH; j = j + 2**i) begin
				g[j] = g[j] | p[j] & g[j - 2**(i-1)];
				p[j] = p[j] & p[j - 2**(i-1)];
			end
		end
	end

	assign CO = g;
endmodule

module \$alu (A, B, CI, BI, X, Y, CO);
	parameter A_SIGNED = 0;
	parameter B_SIGNED = 0;
	parameter A_WIDTH = 1;
	parameter B_WIDTH = 1;
	parameter Y_WIDTH = 1;

	input [A_WIDTH-1:0] A;
	input [B_WIDTH-1:0] B;
	output [Y_WIDTH-1:0] X, Y;

	input CI, BI;
	output [Y_WIDTH-1:0] CO;

	wire [Y_WIDTH-1:0] A_buf, B_buf;
	\$pos #(.A_SIGNED(A_SIGNED), .A_WIDTH(A_WIDTH), .Y_WIDTH(Y_WIDTH)) A_conv (.A(A), .Y(A_buf));
	\$pos #(.A_SIGNED(B_SIGNED), .A_WIDTH(B_WIDTH), .Y_WIDTH(Y_WIDTH)) B_conv (.A(B), .Y(B_buf));

	wire [Y_WIDTH-1:0] AA = A_buf;
	wire [Y_WIDTH-1:0] BB = BI ? ~B_buf : B_buf;

	\$lcu #(.WIDTH(Y_WIDTH)) lcu (.P(X), .G(AA & BB), .CI(CI), .CO(CO));

	assign X = AA ^ BB;
	assign Y = X ^ {CO, CI};
endmodule


// --------------------------------------------------------
// ALU Cell Types: Compare, Add, Subtract
// --------------------------------------------------------

`define ALU_COMMONS(_width, _sub) """
	parameter A_SIGNED = 0;
	parameter B_SIGNED = 0;
	parameter A_WIDTH = 1;
	parameter B_WIDTH = 1;
	parameter Y_WIDTH = 1;

	localparam WIDTH = _width;

	input [A_WIDTH-1:0] A;
	input [B_WIDTH-1:0] B;
	output [Y_WIDTH-1:0] Y;

	wire [WIDTH-1:0] alu_x, alu_y, alu_co;
	wire [WIDTH:0] carry = {alu_co, |_sub};

	\$alu #(
		.A_SIGNED(A_SIGNED),
		.B_SIGNED(B_SIGNED),
		.A_WIDTH(A_WIDTH),
		.B_WIDTH(B_WIDTH),
		.Y_WIDTH(WIDTH)
	) alu (
		.A(A),
		.B(B),
		.CI(|_sub),
		.BI(|_sub),
		.X(alu_x),
		.Y(alu_y),
		.CO(alu_co)
	);

	wire cf, of, zf, sf;
	assign cf = !carry[WIDTH];
	assign of = carry[WIDTH] ^ carry[WIDTH-1];
	assign sf = alu_y[WIDTH-1];
"""

module \$lt (A, B, Y);
	wire [1023:0] _TECHMAP_DO_ = "RECURSION; opt_const -mux_undef -mux_bool -fine;;;";
	`ALU_COMMONS(`MAX(A_WIDTH, B_WIDTH), 1)
	assign Y = A_SIGNED && B_SIGNED ? of != sf : cf;
endmodule

module \$le (A, B, Y);
	wire [1023:0] _TECHMAP_DO_ = "RECURSION; opt_const -mux_undef -mux_bool -fine;;;";
	`ALU_COMMONS(`MAX(A_WIDTH, B_WIDTH), 1)
	assign Y = &alu_x || (A_SIGNED && B_SIGNED ? of != sf : cf);
endmodule

module \$add (A, B, Y);
	wire [1023:0] _TECHMAP_DO_ = "RECURSION; opt_const -mux_undef -mux_bool -fine;;;";
	`ALU_COMMONS(Y_WIDTH, 0)
	assign Y = alu_y;
endmodule

module \$sub (A, B, Y);
	wire [1023:0] _TECHMAP_DO_ = "RECURSION; opt_const -mux_undef -mux_bool -fine;;;";
	`ALU_COMMONS(Y_WIDTH, 1)
	assign Y = alu_y;
endmodule


// --------------------------------------------------------
// Multiply
// --------------------------------------------------------

(* techmap_maccmap *)
module \$macc ;
endmodule

module \$mul (A, B, Y);
	parameter A_SIGNED = 0;
	parameter B_SIGNED = 0;
	parameter A_WIDTH = 1;
	parameter B_WIDTH = 1;
	parameter Y_WIDTH = 1;

	input [A_WIDTH-1:0] A;
	input [B_WIDTH-1:0] B;
	output [Y_WIDTH-1:0] Y;

	wire [1023:0] _TECHMAP_DO_ = "RECURSION; CONSTMAP; opt -purge";

	localparam [ 3:0] CONFIG_WIDTH_BITS = 15;
	localparam [ 0:0] CONFIG_IS_SIGNED = A_SIGNED && B_SIGNED;
	localparam [ 0:0] CONFIG_DO_SUBTRACT = 0;
	localparam [14:0] CONFIG_A_WIDTH = A_WIDTH;
	localparam [14:0] CONFIG_B_WIDTH = B_WIDTH;

	\$macc #(
		.CONFIG({CONFIG_B_WIDTH, CONFIG_A_WIDTH, CONFIG_DO_SUBTRACT, CONFIG_IS_SIGNED, CONFIG_WIDTH_BITS}),
		.CONFIG_WIDTH(15 + 15 + 2 + 4),
		.A_WIDTH(B_WIDTH + A_WIDTH),
		.B_WIDTH(0),
		.Y_WIDTH(Y_WIDTH)
	) _TECHMAP_REPLACE_ (
		.A({B, A}),
		.B(),
		.Y(Y)
	);
endmodule


// --------------------------------------------------------
// Divide and Modulo
// --------------------------------------------------------

module \$__div_mod_u (A, B, Y, R);
	parameter WIDTH = 1;

	input [WIDTH-1:0] A, B;
	output [WIDTH-1:0] Y, R;

	wire [WIDTH*WIDTH-1:0] chaindata;
	assign R = chaindata[WIDTH*WIDTH-1:WIDTH*(WIDTH-1)];

	genvar i;
	generate begin
		for (i = 0; i < WIDTH; i=i+1) begin:stage
			wire [WIDTH-1:0] stage_in;

			if (i == 0) begin:cp
				assign stage_in = A;
			end else begin:cp
				assign stage_in = chaindata[i*WIDTH-1:(i-1)*WIDTH];
			end

			assign Y[WIDTH-(i+1)] = stage_in >= {B, {WIDTH-(i+1){1'b0}}};
			assign chaindata[(i+1)*WIDTH-1:i*WIDTH] = Y[WIDTH-(i+1)] ? stage_in - {B, {WIDTH-(i+1){1'b0}}} : stage_in;
		end
	end endgenerate
endmodule

module \$__div_mod (A, B, Y, R);
	parameter A_SIGNED = 0;
	parameter B_SIGNED = 0;
	parameter A_WIDTH = 1;
	parameter B_WIDTH = 1;
	parameter Y_WIDTH = 1;

	localparam WIDTH =
			A_WIDTH >= B_WIDTH && A_WIDTH >= Y_WIDTH ? A_WIDTH :
			B_WIDTH >= A_WIDTH && B_WIDTH >= Y_WIDTH ? B_WIDTH : Y_WIDTH;

	input [A_WIDTH-1:0] A;
	input [B_WIDTH-1:0] B;
	output [Y_WIDTH-1:0] Y, R;

	wire [WIDTH-1:0] A_buf, B_buf;
	\$pos #(.A_SIGNED(A_SIGNED), .A_WIDTH(A_WIDTH), .Y_WIDTH(WIDTH)) A_conv (.A(A), .Y(A_buf));
	\$pos #(.A_SIGNED(B_SIGNED), .A_WIDTH(B_WIDTH), .Y_WIDTH(WIDTH)) B_conv (.A(B), .Y(B_buf));

	wire [WIDTH-1:0] A_buf_u, B_buf_u, Y_u, R_u;
	assign A_buf_u = A_SIGNED && A_buf[WIDTH-1] ? -A_buf : A_buf;
	assign B_buf_u = B_SIGNED && B_buf[WIDTH-1] ? -B_buf : B_buf;

	\$__div_mod_u #(
		.WIDTH(WIDTH)
	) div_mod_u (
		.A(A_buf_u),
		.B(B_buf_u),
		.Y(Y_u),
		.R(R_u)
	);

	assign Y = A_SIGNED && B_SIGNED && (A_buf[WIDTH-1] != B_buf[WIDTH-1]) ? -Y_u : Y_u;
	assign R = A_SIGNED && B_SIGNED && A_buf[WIDTH-1] ? -R_u : R_u;
endmodule

module \$div (A, B, Y);
	parameter A_SIGNED = 0;
	parameter B_SIGNED = 0;
	parameter A_WIDTH = 1;
	parameter B_WIDTH = 1;
	parameter Y_WIDTH = 1;

	input [A_WIDTH-1:0] A;
	input [B_WIDTH-1:0] B;
	output [Y_WIDTH-1:0] Y;

	\$__div_mod #(
		.A_SIGNED(A_SIGNED),
		.B_SIGNED(B_SIGNED),
		.A_WIDTH(A_WIDTH),
		.B_WIDTH(B_WIDTH),
		.Y_WIDTH(Y_WIDTH)
	) div_mod (
		.A(A),
		.B(B),
		.Y(Y)
	);
endmodule

module \$mod (A, B, Y);
	parameter A_SIGNED = 0;
	parameter B_SIGNED = 0;
	parameter A_WIDTH = 1;
	parameter B_WIDTH = 1;
	parameter Y_WIDTH = 1;

	input [A_WIDTH-1:0] A;
	input [B_WIDTH-1:0] B;
	output [Y_WIDTH-1:0] Y;

	\$__div_mod #(
		.A_SIGNED(A_SIGNED),
		.B_SIGNED(B_SIGNED),
		.A_WIDTH(A_WIDTH),
		.B_WIDTH(B_WIDTH),
		.Y_WIDTH(Y_WIDTH)
	) div_mod (
		.A(A),
		.B(B),
		.R(Y)
	);
endmodule


// --------------------------------------------------------
// Power
// --------------------------------------------------------

module \$pow (A, B, Y);
	parameter A_SIGNED = 0;
	parameter B_SIGNED = 0;
	parameter A_WIDTH = 1;
	parameter B_WIDTH = 1;
	parameter Y_WIDTH = 1;

	input [A_WIDTH-1:0] A;
	input [B_WIDTH-1:0] B;
	output [Y_WIDTH-1:0] Y;

	wire _TECHMAP_FAIL_ = 1;
endmodule


// --------------------------------------------------------
// Equal and Not-Equal
// --------------------------------------------------------

module \$eq (A, B, Y);
	parameter A_SIGNED = 0;
	parameter B_SIGNED = 0;
	parameter A_WIDTH = 1;
	parameter B_WIDTH = 1;
	parameter Y_WIDTH = 1;

	localparam WIDTH = A_WIDTH > B_WIDTH ? A_WIDTH : B_WIDTH;

	input [A_WIDTH-1:0] A;
	input [B_WIDTH-1:0] B;
	output [Y_WIDTH-1:0] Y;

	wire carry, carry_sign;
	wire [WIDTH-1:0] A_buf, B_buf;
	\$pos #(.A_SIGNED(A_SIGNED), .A_WIDTH(A_WIDTH), .Y_WIDTH(WIDTH)) A_conv (.A(A), .Y(A_buf));
	\$pos #(.A_SIGNED(B_SIGNED), .A_WIDTH(B_WIDTH), .Y_WIDTH(WIDTH)) B_conv (.A(B), .Y(B_buf));

	assign Y = ~|(A_buf ^ B_buf);
endmodule

module \$ne (A, B, Y);
	parameter A_SIGNED = 0;
	parameter B_SIGNED = 0;
	parameter A_WIDTH = 1;
	parameter B_WIDTH = 1;
	parameter Y_WIDTH = 1;

	localparam WIDTH = A_WIDTH > B_WIDTH ? A_WIDTH : B_WIDTH;

	input [A_WIDTH-1:0] A;
	input [B_WIDTH-1:0] B;
	output [Y_WIDTH-1:0] Y;

	wire carry, carry_sign;
	wire [WIDTH-1:0] A_buf, B_buf;
	\$pos #(.A_SIGNED(A_SIGNED), .A_WIDTH(A_WIDTH), .Y_WIDTH(WIDTH)) A_conv (.A(A), .Y(A_buf));
	\$pos #(.A_SIGNED(B_SIGNED), .A_WIDTH(B_WIDTH), .Y_WIDTH(WIDTH)) B_conv (.A(B), .Y(B_buf));

	assign Y = |(A_buf ^ B_buf);
endmodule

module \$eqx (A, B, Y);
	parameter A_SIGNED = 0;
	parameter B_SIGNED = 0;
	parameter A_WIDTH = 1;
	parameter B_WIDTH = 1;
	parameter Y_WIDTH = 1;

	localparam WIDTH = A_WIDTH > B_WIDTH ? A_WIDTH : B_WIDTH;

	input [A_WIDTH-1:0] A;
	input [B_WIDTH-1:0] B;
	output [Y_WIDTH-1:0] Y;

	wire carry, carry_sign;
	wire [WIDTH-1:0] A_buf, B_buf;
	\$pos #(.A_SIGNED(A_SIGNED), .A_WIDTH(A_WIDTH), .Y_WIDTH(WIDTH)) A_conv (.A(A), .Y(A_buf));
	\$pos #(.A_SIGNED(B_SIGNED), .A_WIDTH(B_WIDTH), .Y_WIDTH(WIDTH)) B_conv (.A(B), .Y(B_buf));

	assign Y = ~|(A_buf ^ B_buf);
endmodule

module \$nex (A, B, Y);
	parameter A_SIGNED = 0;
	parameter B_SIGNED = 0;
	parameter A_WIDTH = 1;
	parameter B_WIDTH = 1;
	parameter Y_WIDTH = 1;

	localparam WIDTH = A_WIDTH > B_WIDTH ? A_WIDTH : B_WIDTH;

	input [A_WIDTH-1:0] A;
	input [B_WIDTH-1:0] B;
	output [Y_WIDTH-1:0] Y;

	wire carry, carry_sign;
	wire [WIDTH-1:0] A_buf, B_buf;
	\$pos #(.A_SIGNED(A_SIGNED), .A_WIDTH(A_WIDTH), .Y_WIDTH(WIDTH)) A_conv (.A(A), .Y(A_buf));
	\$pos #(.A_SIGNED(B_SIGNED), .A_WIDTH(B_WIDTH), .Y_WIDTH(WIDTH)) B_conv (.A(B), .Y(B_buf));

	assign Y = |(A_buf ^ B_buf);
endmodule


// --------------------------------------------------------
// Parallel Multiplexers
// --------------------------------------------------------

module \$pmux (A, B, S, Y);
	parameter WIDTH = 1;
	parameter S_WIDTH = 1;

	input [WIDTH-1:0] A;
	input [WIDTH*S_WIDTH-1:0] B;
	input [S_WIDTH-1:0] S;
	output [WIDTH-1:0] Y;

	wire [WIDTH-1:0] Y_B;

	genvar i, j;
	generate
		wire [WIDTH*S_WIDTH-1:0] B_AND_S;
		for (i = 0; i < S_WIDTH; i = i + 1) begin:B_AND
			assign B_AND_S[WIDTH*(i+1)-1:WIDTH*i] = B[WIDTH*(i+1)-1:WIDTH*i] & {WIDTH{S[i]}};
		end:B_AND
		for (i = 0; i < WIDTH; i = i + 1) begin:B_OR
			wire [S_WIDTH-1:0] B_AND_BITS;
			for (j = 0; j < S_WIDTH; j = j + 1) begin:B_AND_BITS_COLLECT
				assign B_AND_BITS[j] = B_AND_S[WIDTH*j+i];
			end:B_AND_BITS_COLLECT
			assign Y_B[i] = |B_AND_BITS;
		end:B_OR
	endgenerate

	assign Y = |S ? Y_B : A;
endmodule


// --------------------------------------------------------
// LUTs
// --------------------------------------------------------

`ifndef NOLUT
module \$lut (A, Y);
	parameter WIDTH = 1;
	parameter LUT = 0;

	input [WIDTH-1:0] A;
	output Y;

	assign Y = LUT[A];
endmodule
`endif

