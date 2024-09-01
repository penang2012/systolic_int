import numpy as np
import struct

M = 16
K = 16
N = 16
ROW = 8
COL = 8

scale_out = 1024.0
min_out = 0.0

def read_output_file_to_matrix_int(filename, A, a, B, b):
    
    matrix = np.zeros((A, B), dtype=np.int32)

    with open(filename, 'r') as f:
        for j in range(0, B, b * 2):
            for i in range(0, A, a * 2):
                for i_in in range (0, 2 * a, a):
                    for j_in in range (0, 2 * b, b):
                        for k in range(0, a, 1):
                            for l in range(0, b ,1):
                                line = f.readline().strip()
                                value = int(line, 16)
                                # Reconstruct the matrix element
                                matrix[i + i_in + k][j + j_in + l] = value
    
    return matrix

def read_output_file_to_matrix_bf16(filename, A, a, B, b):
    
    matrix = np.zeros((A, B), dtype=np.float32)

    with open(filename, 'r') as f:
        for j in range(0, B, b * 2):
            for i in range(0, A, a * 2):
                for i_in in range (0, 2 * a, a):
                    for j_in in range (0, 2 * b, b):
                        for k in range(0, a, 1):
                            for l in range(0, b ,2):
                                line = f.readline().strip()
                                # Split the line into two 4-character segments
                                first_word_hex = line[:4]
                                second_word_hex = line[4:]
                                
                                # Convert hex strings to integers
                                first_word = int(first_word_hex, 16)
                                second_word = int(second_word_hex, 16)
                                
                                matrix[i + i_in + k][j + j_in + l + 1] = first_word
                                matrix[i + i_in + k][j + j_in + l] = second_word
    
    return matrix

def read_output_file_to_matrix_fp32(filename, A, a, B, b):
    matrix = np.zeros((A, B), dtype=np.float32)
    with open(filename, 'r') as f:
        for j in range(0, B, 1):
            for i in range(0, A, 1):
                    line = f.readline().strip()
                    # Convert the hexadecimal string back to float32
                    int_value = int(line, 16)
                    packed_value = struct.pack('>I', int_value)
                    # Unpack the binary representation into a float32 value
                    float_value = struct.unpack('>f', packed_value)[0]

                    matrix[i][j] = float_value
    return matrix




out_int8 = read_output_file_to_matrix_int("evaluate/output_int.txt", M, ROW, N, COL)
out_fp32 = read_output_file_to_matrix_fp32("evaluate/output_fp32.txt", M, ROW, N, COL)
out_bf16 = read_output_file_to_matrix_fp32("evaluate/output_bfloat16.txt", M, ROW, N, COL)

with open("evaluate/output_util.txt", 'r') as f:
    line = f.readline().strip()
    scale_ActW = float(line)
    line = f.readline().strip()
    abs_ActW = float(line)


min_out = np.min(np.array(out_int8))
max_out = np.max(np.array(out_int8))

abs_out = max(abs(max_out), abs(min_out))

scale_out = (2 * abs_out) / 255.0

out_uint8_to_float = scale_ActW * (out_int8) # Need to change!

print("fp32: \n", out_fp32)
print("int : \n", out_uint8_to_float)
print("bf16: \n", out_bf16)


error_int8 = np.mean((out_fp32 - out_uint8_to_float) ** 2)

error_bf16 = np.mean((out_fp32 - out_bf16) ** 2)

print("scale_AbsW: ", scale_out, ", abs_ActW: ", min_out)

print(" RMSE ERROR between fp32 format matrix multiplication")
print(" int8 quantization error: ", error_int8)
print(" bfloat16 quantization error: ", error_bf16)

