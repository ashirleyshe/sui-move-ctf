from z3 import *

ciphertext = [19, 16, 17, 11, 9, 21, 18, 
            2, 3, 22, 7, 4, 25, 21, 5, 
            7, 23, 6, 23, 5, 13, 3, 5, 
            9, 16, 12, 22, 14, 3, 14, 12, 
            22, 18, 4, 3, 9, 2, 19, 5, 
            16, 7, 20, 1, 11, 18, 23, 4, 
            15, 20, 5, 24, 9, 1, 12, 5, 
            16, 10, 7, 2, 1, 21, 1, 25, 
            18, 22, 2, 2, 7, 25, 15, 7, 10
]

complete_plaintext = [4, 15, 11, 0, 13, 4, 19, 19, 19]

plain = [ Int('plain_'+str(i)) for i in range(3*3*7) ]

complete_plaintext = complete_plaintext + plain

# solve data2
key = [ Int('key_'+str(i))   for i in range(3*3) ]
a11, a12, a13 = key[0:3]
a21, a22, a23 = key[3:6]
a31, a32, a33 = key[6:9]

s = Solver()
for k in key:
    s.add(And(k >= 0, k < 26))
for i in range(0, 9, 3):
    p11,p21,p31 = complete_plaintext[i:i+3]
    c11 = ( (a11 * p11) + (a12 * p21) + (a13 * p31) ) % 26
    c21 = ( (a21 * p11) + (a22 * p21) + (a23 * p31) ) % 26
    c31 = ( (a31 * p11) + (a32 * p21) + (a33 * p31) ) % 26

    s.add(And(c11 == ciphertext[i], c21 == ciphertext[i+1], c31 == ciphertext[i+2]))
s.check()

m = s.model()
key = [m.eval(k) for k in key]

print(key)

# solve data1
a11, a12, a13 = key[0:3]
a21, a22, a23 = key[3:6]
a31, a32, a33 = key[6:9]

data1 = []
for i in range(3*3, len(complete_plaintext), 3):
    s = Solver()

    p11,p21,p31 = complete_plaintext[i:i+3]
    s.add(And(p11 >= 0, p21 >= 0, p31 >= 0))
    c11 = ( (a11 * p11) + (a12 * p21) + (a13 * p31) ) % 26
    c21 = ( (a21 * p11) + (a22 * p21) + (a23 * p31) ) % 26
    c31 = ( (a31 * p11) + (a32 * p21) + (a33 * p31) ) % 26

    s.add(And(c11 == ciphertext[i], c21 == ciphertext[i+1], c31 == ciphertext[i+2]))
    s.check()
    m = s.model()
    data1 += [m.eval(p11), m.eval(p21), m.eval(p31)]

print(data1)