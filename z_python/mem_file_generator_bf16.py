import numpy as np

def to_bfloat16(value):
    f32 = np.float32(value)
    return np.uint16(f32.view(np.uint32) >> 16)

def create_mem_file_from_matrix_bf16(filename, matrix, A, a, B, b):
    """
    Create a .mem file from a 2D matrix.
    
    :param filename: The name of the file to create (e.g., "matrix.mem").
    :param matrix: A 2D numpy array (matrix) of integers.
    :param format: 'hex' for hexadecimal format, 'bin' for binary format.
    """
    
    # 8x8 행렬의 각 요소를 bfloat32로 변환
    bfloat_matrix = np.vectorize(to_bfloat16)(matrix)

    with open(filename, 'w') as f:
        for i in range(0, A, a):
            for j in range(0, B, b):
                for k in range(0, a, 1):
                    for l in range(0, b, 2):
                        # 두 원소를 16진수 형식으로 합침
                        combined = f"{bfloat_matrix[i + k][j + l + 1]:04x}{bfloat_matrix[i + k][j + l]:04x}"  
                        f.write(combined+"\n")  # Write as 8-digit hexadecimal


def create_output_file_from_matrix_bf16(filename, matrix):   
    # 8x8 행렬의 각 요소를 bfloat32로 변환
    bfloat_matrix = np.vectorize(to_bfloat32)(matrix)

    with open(filename, 'w') as f:
        
        for j in range(0,col, tile_col * 2):
            for i in range(0,row, tile_row * 2):
                for i_in in range (0, 2 * tile_row, tile_row):
                    for j_in in range (0, 2 * tile_col, tile_col):
                        for k in range(0,tile_row,1):
                            for l in range(0,tile_col,2):
                                # 두 원소를 16진수 형식으로 합침
                                combined = f"{bfloat_matrix[i + i_in + k][j + j_in +  l + 1]:04x}{bfloat_matrix[i + i_in + k][j + j_in +  l]:04x}"  
                                f.write(combined+"\n")  # Write as 8-digit hexadecimal



# Step 1: Create a 64x64 matrix with sequential numbers
# matrix = np.arange(1, 256 * 256 + 1).reshape(256 , 256) / 1024

row = 256
col = 256
tile_row = 8
tile_col = 8

                  
                
# Step 2: Write the matrix to a .mem file
# create_mem_file_from_matrix("activation.mem", matrix)

# create_mem_file_from_matrix("output.mem", matrix_out)
