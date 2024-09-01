# SYSTOLIC ARRAY INT

## 차이점
integer연산을 테스트 하기 위한 모듈. 
1) systolic array: integer mac.
2) Quantization unit.
3) Dequantization unit.

---
## 개요
지정된 Activation BRAM과 Weight BRAM 사이의 Multiplication을 수행 후, 연산 결과를 Output buffer에 저장함.
사용할 Act / Weight BRAM의 데이터를 Systolic Array에서 곱연산 진행.
연산 결과는 PSUM buffer에서 저장.
Output Buffer로 데이터 옮기라는 신호 입력 시, PSUM buffer의 결과를 Output buffer로 옮긴다.

## BRAM 저장 순서
- (8x8) 타일 단위 저장. 타일은 행  -> 열 방향 저장
  
    e.g.) 4x4 tiles:
    [1][2][3][4][16][ ][ ][]
    [5][6][7][8] ...
    [9][10][][ ] ...
    [][ ][ ][15][ ][ ][ ][31]
    [32]...
    ...

- BRAM 저장 형식 : 32bit = 2 x 16bit. Floating point data = 32bit.

## Input / Output Ports
__Input__
- clk : clock
- rstn : reset_n
- A, B, C (8? bit): Size of Activation, Weight tile 크기.
  - 실제 계산하는 sub-tile의 크기. 각 타일이 BRAM에 (_ x _) 올라와있는지.
  - Activation_sub : (A x B) { elements: 8A x 8B 개 존재.}
  - Weight_sub : (B x C) {elements:  8B x 8C개}
  
- start (1 bit)
- opcode (2 bits) : 연산 방향. {Act, Weight}, 0: 가로방향, 1: 세로 방향.
  - 00: Psum을 1xC 크기 먼저 계산, A개 연산.
  - 01: Psum을 1x1 타일 먼저 계산, 나머지 타일 C -> A 순서로 생성
  - 10: 전체 PSUM을 모두 만든다. 
  - 11: Psum을 Ax1 먼저 계산 후, C개 생성
- a_sel (1 bit): Activation buffer select.
- w_sel (1 bit): Weight buffer select.
- o_sel (1 bit): Output buffer select.
- is_firstpsum (1 bit) : 이전 psum 데이터를 활용할 지 지정.
  - 0: use stored psum data 
  - 1: do not use previous psum data.
- is_outputload (1 bit) : Output BRAM에 데이터 저장 할 것인지 지정.
  - 0: psum을 output에 저장하지 않는다.
  - 1: 마지막 psum 결과를 output BRAM에 저장. 


__Output__
- busy (1 bit) : 연산이 진행중일 때 1, else 0
- done (1 bit) : 연산이 끝났을 때 1, else 0


_Control Signals_ (여기 이름 수정함.)
정확한 port는 설명 하단에 기록.
- ?_buf?_en, ?_buf?_we, ?_buf?_addr : 
  - BRAM Activation / Weight / Output control signals
  - Buffer data line은 직접 연결.
- ?_allign_rstn, ?_allign_en, ?_allign_we, ?_allign_re: 
  - Allign unit control signals.
- sys_array_control : systolic array control signal.
  - 0: Activation load
  - 1: Weight load
- psum_sel: 어떤 psum buffer에 저장할지 결정.
- first_psum: psum buffer가 처음인지 여부 알려줌. 



## 연산 순서.
opcode에 따른 연산 순서 차이가 생기며, For문 4개의 cycle을 가진다.
_처음에 구현한 것과 address 저장 차이에 의한 값 차이 존재_
    
    opcode 00: I = A, J = B, K = C, L = 1
    opcode 01: I = A, J = C, K = B, L = 1
    opcode 10: I = 1, J = B, K = C, L = A
    opcode 11: I = 1, J = C, K = B, L = A

    for(i, i<I)
        for(j, j<J)
            for(k, k<K)
              // 32 bit: 2words per address. 
              // addr <= (ROW * COL / 2) * (tile_index) + inside_index
              
              for(idx_w = 0; idx_w < ROW; idx_w += 1)
                w_addr <= ROW * (J * k + j) + idx_w

              for(l, l <L)
                  for(idx_a = 0; idx_a < COL, idx_a += 1)
                    a_addr <= COL * (K * (l + L * i) + k) + idx_a
                  // 이 address부터 64개의 원소 (32 data), 각 타일 ROW * COL = 8*8 데이터
                  
                  for (idx_p = 0; idx_p < ROW, idx_p += 1)
                    if(opcode[0] = 1): psum_addr <= ROW * (j + K * (l + L * i)) + idx_p
                    else             : psum-addr <= ROW * (k + J * (l + L * i)) + idx_p

## REGISTER
1. STATE
   1. IDLE: 2'b00
   2. WEIGHTLOAD: 2'b01
   3. MULTIPLY: 2'b10
   4. OUTPUTLOAD: 2'b11
2. I, J, K, L : For 문 반복 횟수. opcode에 따른 결정
3. idx_a, idx_w, idx_p : 각 타일 내부에서 address

# How to run  

## INPUT DATA / OUTPUT DATA:
input data: .mem file. 
파이썬 파일로 mem_file_generator.py를 통해서 mem 파일을 생성할 수 있다.

vivado에서 mem파일 업로드 해서 접근.

output data: _VIVADO파일명_\_VIVADO파일명_.sim\sim_1\behav\xsim\output.txt" 에 저장됨.

# BRAM 설정 방법.
VIVADO의 ip generator에서 BRAM을 지정한다.
언급하지 않은 설정은 default로 설정.

1. BRAM_W32x2048_R128 : Activation, Weight BRAM
   1. IP catalog: block memory generator
   2. BASIC: native, single port ram.
   3. Port A options
      1. write data width : 32  | write addr : 2048
      2. read data width: 128 | read addr: 512
      3. operating mode: no change
      4. Use ENA pin
      5. Primitive register : X, Core Output register: X
2. BRAM_W128x32_R32x128 : Output BRAM
   1. IP catalog: block memory generator
   2. BASIC: native, single port ram.
   3. Port A options
      1.  write data width : 128  | write addr : 32
      2. read data width: 32 | read addr: 128
      3. operating mode: no change
      4. Use ENA pin
      5. Primitive register : X, Core Output register: X
3. BRAM_32x8x32 : PSUM BRAM. __DIFFERENT__
   1. IP catalog: block memory generator
   2. BASIC: native, single port ram.
   3. Port A options
      1. __write data width : 256  | read addr : 32__
      2. __read data width: 256 | write addr: 32__
      3. operating mode: no change
      4. Use ENA pin
      5. __Primitive register : O, Core Output register: X__



__Port 추가시 업데이트__

    .clk,
    .rstn,

    .A,
    .B,
    .C,

    .start,
    .opcode,
    .a_sel,
    .w_sel,
    .o_sel,
    .is_firstpsum,
    .is_outputload,

    .busy,
    .done,    
    
    .w_buf0_en,
    .w_buf0_we,
    .w_buf0_addr,

    .w_buf1_en,
    .w_buf1_we,
    .w_buf1_addr,

    .a_buf0_en,
    .a_buf0_we,
    .a_buf0_addr,

    .a_buf1_en,
    .a_buf1_we,
    .a_buf1_addr,

    .a_allign_rstn,
    .a_allign_en,
    .a_allign_we,
    .a_allign_re,

    .sys_array_control,

    .p_allign_rstn,
    .p_allign_en,
    .p_allign_we,
    .p_allign_re,

    .psum_en,
    .psum_we,
    .psum_addr,
    .psum_prev_addr,
    .psum_sel,
    .first_psum,

    .o_buf0_en,
    .o_buf0_we,
    .o_buf0_addr,

    .o_buf1_en,
    .o_buf1_we,
    .o_buf1_addr    

