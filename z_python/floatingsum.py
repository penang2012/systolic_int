import struct

# Step 1: Convert hexadecimal to floating-point
hex1 = 0x46f94200
hex2 = 0x46f549fc


float1 = struct.unpack('!f', struct.pack('!I', hex1))[0]
float2 = struct.unpack('!f', struct.pack('!I', hex2))[0]

# Step 2: Perform the addition
result = float1 - float2

# Step 3: Convert the result back to hexadecimal
result_hex = struct.unpack('!I', struct.pack('!f', result))[0]

# Print results
print(float1, float2, result, hex(result_hex))

