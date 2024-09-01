import numpy as np
import struct
import time

# Function to convert float32 to hex
def float32_to_hex(float_num):
    int_bits = struct.unpack('!I', struct.pack('!f', float_num))[0]
    return hex(int_bits)

# Function to convert hex to float32
def hex_to_float32(hex_str):
    int_bits = int(hex_str, 16)
    return struct.unpack('!f', struct.pack('!I', int_bits))[0]

# Function to convert matrix from float32 to hex
def matrix_to_hex(matrix):
    return [[float32_to_hex(matrix[i][j]) for j in range(matrix.shape[1])] for i in range(matrix.shape[0])]

# Function to convert matrix from hex to float32
def hex_to_matrix(hex_matrix):
    return np.array([[hex_to_float32(hex_matrix[i][j]) for j in range(len(hex_matrix[0]))] for i in range(len(hex_matrix))])

# Create matrix A (16x32) with sequential values starting from 1.0
N = 256
K = 256
M = 256

A = 16
B = 256
C = 16

ACT = np.arange(1, 256 * 256 + 1).reshape(256, 256) / 1024
WEIGHT = np.arange(1, 256 * 256 + 1).reshape(256,256) / 1024



WEIGHT = WEIGHT.astype(np.float32)
ACT = ACT.astype(np.float32)
# # Create two matrices with random FP32 values
# A = np.random.rand(16, 32).astype(np.float32)
# B = np.random.rand(32, 16).astype(np.float32)

# Convert matrices to hexadecimal format

def to_bfloat32(value):
    f32 = np.float32(value)
    return np.uint16(f32.view(np.uint32) >> 16)


def to_float(bfloat16_value):
    # Reinterpret the 16-bit bfloat16 as a 32-bit float by shifting the bits left by 16
    bfloat32 = np.uint32(bfloat16_value) << 16
    
    # Convert to float32
    float_value = np.frombuffer(bfloat32.tobytes(), dtype=np.float32)[0]
    
    # Convert the float32 value to an integer
    return float_value

ACT_HEX = np.vectorize(to_bfloat32)(ACT)
WEIGHT_HEX = np.vectorize(to_bfloat32)(ACT)

tile_a = 2
tile_ap = 3
tile_b = 0
tile_bp = 31
tile_c = 0
tile_cp = 1
ACT_SUB = ACT[tile_a * 8 + 0 : tile_ap * 8 + 8, tile_b * 8 + 0 : tile_bp * 8 + 8]
WEIGHT_SUB = WEIGHT[tile_b * 8 + 0 : tile_bp * 8 + 8, tile_c * 8 + 0 : tile_cp * 8 + 8]
ACT_SUB_HEX = np.vectorize(to_bfloat32)(ACT_SUB)
WEIGHT_SUB_HEX = np.vectorize(to_bfloat32)(WEIGHT_SUB)

ACT_SUB_INT = np.vectorize(to_float)(ACT_SUB_HEX)
WEIGHT_SUB_INT = np.vectorize(to_float)(WEIGHT_SUB_HEX)

# Perform matrix multiplication

PSUM = np.dot(ACT_SUB_INT, WEIGHT_SUB_INT)

# start_time = time.time()
# OUT = np.dot(ACT, WEIGHT)
# end_time = time.time()

# time_taken = end_time - start_time



# Convert result matrix to hexadecimal format
PSUM_HEX = matrix_to_hex(PSUM)

# Print the input matrices in hex format
print("Matrix ACT_SUB (16x256) in Hexadecimal:")
for row in ACT_SUB_HEX:
    print([f"{i:04x}" for i in row ])

print("Matrix ACT_SUB (16x256) in INT:")
for row in ACT_SUB:
    print([i for i in row ])

        
# for i in range(0,16,8):
#     for j in range(0,7,8):
#         for m in range(8):
#             for n in range(8):
#                 print(ACT_SUB_HEX[i + m][j + n] [2:6], end = " ")
        #     print()
        # print("----------------------------------------------")
        

print("\nMatrix B_SUB (256x16) in Hexadecimal:")
for row in WEIGHT_SUB_HEX:
    print([f"{i:04x}" for i in row ])

print("Matrix WEIGHT_SUB (16x256) in INT:")
for row in WEIGHT_SUB:
    print([i for i in row ])
    

# Print the result matrix in hex format
print("\nResult Matrix C (16x16)) in Hexadecimal:")
# for row in PSUM_HEX:
#     print(row)

for i in range(0, 8 * (tile_ap - tile_a + 1), 8):
    for j in range(0, 8 * (tile_cp - tile_c + 1), 8):
        for m in range(8):
            print([PSUM_HEX[i + m][j + n] for n in range(8)])

# Optional: Print the result matrix in floating-point format
# print("\nResult Matrix C (16x16) in Floating Point:")
# print(PSUM)

# print(f"TIME FOR MULTIPLICATION IN PYTHON: {time_taken:.8f} s")