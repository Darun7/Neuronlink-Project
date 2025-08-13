module half_adder (
    input  wire a,      // First input bit
    input  wire b,      // Second input bit
    output wire sum,    // Sum = a XOR b
    output wire carry   // Carry = a AND b
);

    assign sum   = a ^ b;
    assign carry = a & b;

endmodule
