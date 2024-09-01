import numpy as np

def create_output_file_from_matrix(filename, matrix, A, a, B, b):
    
    with open(filename, 'w') as f:
        for j in range(0, B, b * 2):
            for i in range(0, A, a * 2):
                for i_in in range (0, 2 * a, a):
                    for j_in in range (0, 2 * b, b):
                        for k in range(0, a, 1):
                            for l in range(0, b ,1):
                                # 두 원소를 16진수 형식으로 합침
                                combined = f"{matrix[i + i_in + k][j + j_in +  l]:02x}"  
                                f.write(combined+"\n")  # Write as 8-digit hexadecimal

M = 256
K = 256
N = 256
ROW = 8
COL = 8


# Step 1: Create a 64x64 matrix with sequential numbers
activation = np.random.randint(low=0, high=255, size=(M, K))
weight = np.random.randint(low=0, high=255, size=(K, N))

output = np.dot(activation, weight) >> 17


row = 256
col = 256
tile_row = 8
tile_col = 8


create_output_file_from_matrix("output.mem", output, 256, 8, 256, 8)
