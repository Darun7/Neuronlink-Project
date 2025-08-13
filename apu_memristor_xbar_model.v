module apu_memristor_xbar_model #(
    parameter N = 4, // number of input lines
    parameter M = 4  // number of output lines
)(
    input  real vin[N],       // analog input voltages
    output real iout[M]       // output currents
);

    // Example conductance matrix (Siemens)
    real G[N][M] = '{
        '{1e-6, 2e-6, 1e-6, 0.5e-6},
        '{2e-6, 1e-6, 2e-6, 0.5e-6},
        '{1e-6, 1e-6, 3e-6, 1e-6},
        '{0.5e-6, 2e-6, 1e-6, 2e-6}
    };

    integer j, k;

    always_comb begin
        for (j = 0; j < M; j = j + 1) begin
            iout[j] = 0.0;
            for (k = 0; k < N; k = k + 1) begin
                iout[j] += vin[k] * G[k][j]; // Ohm's Law: I = G × V
            end
        end
    end

endmodule
