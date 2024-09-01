import numpy as np

M = 256
K = 256
N = 256
ROW = 8
COL = 8

def to_bfloat32(value):
    f32 = np.float32(value)
    return np.uint16(f32.view(np.uint32) >> 16)

def create_mem_file_from_matrix_int(filename, matrix, A, a, B, b):
    """
    Create a .mem file from a 2D matrix.
    
    :param filename: The name of the file to create (e.g., "matrix.mem").
    :param matrix: A 2D numpy array (matrix) of integers.
    :param format: 'hex' for hexadecimal format, 'bin' for binary format.
    """
    
    # 8x8 행렬의 각 요소를 bfloat32로 변환
    # bfloat_matrix = np.vectorize(to_bfloat32)(matrix)

    with open(filename, 'w') as f:
        for i in range(0, A, a):
            for j in range(0, B, b):
                for k in range(0, a, 1):
                    for l in range(0, b, 4):
                        # 두 원소를 16진수 형식으로 합침
                        combined = f"{matrix[i + k][j + l + 3]:02x}{matrix[i + k][j + l + 2]:02x}{matrix[i + k][j + l + 1]:02x}{matrix[i + k][j + l]:02x}"  
                        f.write(combined+"\n")  # Write as 8-digit hexadecimal


def create_output_file_from_matrix_int(filename, matrix, A, a, B, b):
    
    with open(filename, 'w') as f:
        for j in range(0, B, b * 2):
            for i in range(0, A, a * 2):
                for i_in in range (0, 2 * a, a):
                    for j_in in range (0, 2 * b, b):
                        for k in range(0, a, 1):
                            for l in range(0, b ,1):
                                # 두 원소를 16진수 형식으로 합침
                                combined = f"{matrix[i + i_in + k][j + j_in + l]:08x}"  
                                f.write(combined+"\n")  # Write as 8-digit hexadecimal


def create_output_file_from_matrix_fp32(filename, matrix, A, a, B, b):
    
    with open(filename, 'w') as f:
        for j in range(0, B, 1):
            for i in range(0, A, 1):
                combined = f"{matrix[i][j]:08x}"  
                f.write(combined+"\n")  # Write as 8-digit hexadecimal



# Step 1: Create a 256x256 matrix with random numbers in (0,255)
activation = np.random.randint(low=0, high=255, size=(M, K))
weight = np.random.randint(low=0, high=255, size=(K, N))

output = np.dot(activation, weight)
                
# Step 2: Write the matrix to a .mem file
create_mem_file_from_matrix_int("weight.mem", weight, K, ROW, N, COL)
create_mem_file_from_matrix_int("activation.mem", activation, M, ROW, N, COL)

create_output_file_from_matrix_int("output_predicted.txt", output, M, ROW, N, COL)
