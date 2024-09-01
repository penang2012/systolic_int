import numpy as np

def to_bfloat16(value):
    f32 = np.float32(value)
    return np.uint16(f32.view(np.uint32) >> 16)

def to_fp32(value):
    f32 = np.float32(value)
    return np.uint32(f32.view(np.uint32))

def create_mem_file_from_matrix_int(filename, matrix, A, a, B, b):
    
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


def create_output_file_from_matrix_fp32(filename, matrix, A, B):
    fp32_matrix = np.vectorize(to_fp32)(matrix)   
    with open(filename, 'w') as f:
        for j in range(0, B, 1):
            for i in range(0, A, 1):
                combined = f"{fp32_matrix[i][j]:08x}"  
                f.write(combined+"\n")  # Write as 8-digit hexadecimal


def float32_to_bfloat16(float32_array):
    # Step 1: Convert float32 to int32 to manipulate the bits directly
    int_rep = float32_array.view(np.int32)
    
    # Step 2: Isolate the guard bit (bit 16) and sticky bits (bits 15-0)
    guard_bit = (int_rep >> 16) & 0x1
    sticky_bits = (int_rep & 0xFFFF) != 0  # If any of the lower 16 bits are 1, sticky_bits is True

    # Step 3: Truncate the mantissa to 7 bits and shift the exponent/mantissa down
    bfloat16_rep = int_rep & 0xFFFF0000

    # Step 4: Apply rounding
    round_up = guard_bit & (sticky_bits | ((bfloat16_rep >> 16) & 0x1))  # Round to nearest, ties to even
    bfloat16_rep += round_up << 16
    # Step 5: Convert back to float32 (with bfloat16 precision)
    return np.int32(bfloat16_rep).view(np.float32)


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