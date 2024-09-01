import numpy as np

def decimal_to_bfloat32(matrix):
    # bfloat32를 만들기 위해 numpy의 float32로 변환 후 상위 16비트를 사용
    def to_bfloat32(value):
        f32 = np.float32(value)
        return np.uint16(f32.view(np.uint32) >> 16)
    
    # 8x8 행렬의 각 요소를 bfloat32로 변환
    bfloat_matrix = np.vectorize(to_bfloat32)(matrix)

    # bfloat32 형식을 텍스트로 변환
    rows = []
    for row in bfloat_matrix:
        row_text = ""
        for i in range(0, len(row), 2):
            combined = f"{row[i]:04X}{row[i+1]:04X}"  # 두 원소를 16진수 형식으로 합침
            row_text += combined
            if i < len(row) - 1:
                row_text += ","
        rows.append(row_text)

    # 최종 결과를 줄 바꿈으로 연결
    result = "\n".join(rows)
    result = result + "\n"
    return result

# 테스트 행렬 예시
# matrix = np.random.rand(8, 8) * 100  # 0~100 사이의 랜덤 값으로 구성된 8x8 행렬
matrix = np.arange(1, 256*256+1).reshape(256, 256) # 1~64의 연속적인 행렬
for i in range(32):
    for j in range(2,4):
        output_text = decimal_to_bfloat32(matrix[8*i:8*i+8,8*j:8*j+8])
        print(output_text)


