import numpy as np

from make_mem import *

M = 16
K = 16
N = 16
ROW = 8
COL = 8

# Step 1: Create a floating point matrix
Act_fp32 = np.random.randn(M, K).astype(np.float32)
W_fp32 = np.random.randn(K, N).astype(np.float32)

# Step 2: Quantize to uint8
# Determine scaling factors
min_Act, max_Act = np.min(Act_fp32), np.max(Act_fp32)
min_W, max_W = np.min(W_fp32), np.max(W_fp32)

abs_Act = max(abs(min_Act), abs(max_Act))
abs_W = max(abs(min_W), abs(max_W))
 
scale_Act = (2 * abs_Act) / 255.0
scale_W = (2 * abs_W) / 255.0

Act_int8 = np.round((Act_fp32) / scale_Act).astype(np.int8)
W_int8 = np.round((W_fp32) / scale_W).astype(np.int8)

Act_bfloat16 = float32_to_bfloat16(Act_fp32)
W_bfloat16 = float32_to_bfloat16(W_fp32)



# # Step 3: Matrix multiplication with quantized matrices
# # The result will be in a larger bit-width (int32 for safety)

Out_fp32 = np.dot(Act_fp32, W_fp32)
Out_int32 = np.dot(Act_int8.astype(np.int32), W_int8.astype(np.int32))
Out_bfloat16 = np.dot(Act_bfloat16, W_bfloat16)

# # Step 4: int8, bfloat 16 Matrix to mem files.

create_mem_file_from_matrix_int("evaluate/weight_int.mem", W_int8, K, ROW, N, COL)
create_mem_file_from_matrix_int("evaluate/activation_int.mem", Act_int8, M, ROW, N, COL)

create_mem_file_from_matrix_bf16("evaluate/weight_bfloat16.mem", W_bfloat16, K, ROW, N, COL)
create_mem_file_from_matrix_bf16("evaluate/activation_bfloat16.mem", Act_bfloat16, M, ROW, N, COL)

create_output_file_from_matrix_fp32("evaluate/output_fp32.txt", Out_fp32, M, N)
create_output_file_from_matrix_int("evaluate/output_int.txt", Out_int32, M, ROW, N, COL)
create_output_file_from_matrix_fp32("evaluate/output_bfloat16.txt", Out_bfloat16, M, N)

# Check: print matrix data.

scale_ActW = scale_Act * scale_W
abs_ActW = abs_Act * abs_W  # Approximation for dequantization.
with open("evaluate/output_util.txt", 'w') as f:
    f.write(f"{scale_ActW}")
    f.write("\n")
    f.write(f"{abs_ActW}")

# C_fp32 = C_int32.astype(np.float32) * scale_C + min_C

Act_int_to_fp = Act_int8 * scale_Act
W_int_to_fp = W_int8 * scale_W

print("Original Matrix Activation (FP32):\n", Act_fp32[0])
print("Quantized Matrix Activation (int8):\n", Act_int_to_fp[0])
print("Quantized Matrix Activation (bfloat16):\n", Act_bfloat16[0])
print("Original Matrix Weight (FP32):\n", W_fp32[0])
print("Quantized Matrix Weight (int8):\n", W_int_to_fp[0])
print("Quantized Matrix Weight (bfloat16):\n", W_bfloat16[0])


print("Quantized Matrix Output:\n", Out_fp32[0])
