from z3 import *

B_hint = [
      4, 15, 11,  0, 13,  4, 19, 19, 19
]
C = [
     [19, 16, 17, 11,  9, 21, 18,  2,  3],
     [22,  7,  4, 25, 21,  5,  7, 23,  6],
     [23,  5, 13,  3,  5,  9, 16, 12, 22],
     [14,  3, 14, 12, 22, 18,  4,  3,  9],
     [ 2, 19,  5, 16,  7, 20,  1, 11, 18],
     [23,  4, 15, 20,  5, 24,  9,  1, 12],
     [ 5, 16, 10,  7,  2,  1, 21,  1, 25],
     [18, 22,  2,  2,  7, 25, 15,  7, 10],
]

A = [Int('A_%s' % (i+1)) for i in range(9)]
B = [[Int('B_%s_%s' % (j+1, i+1)) for i in range(9)] for j in range(8)]
u = [[Int('u_%s_%s' % (j+1, i+1)) for i in range(9)] for j in range(8)]

s = Solver()
for i in range(9):
    s.add(B[0][i] == B_hint[i])
    s.add(A[i] >= 0)

for k in range(8):
    for j in range(3):
        s.add(B[k][3*j] >=0)
        s.add(B[k][3*j+1] >=0)
        s.add(B[k][3*j+2] >=0)
        for i in range(3):
            s.add(u[k][3*j+i] >=0)
            s.add( A[3*i]*B[k][3*j] + A[3*i+1]*B[k][3*j+1] + A[3*i+2]*B[k][3*j+2] == 26*u[k][3*j+i] + C[k][3*j+i])

print (s.check())
m = s.model()

strA = str(m[A[0]])
for i in range(1,9):
    strA = strA + ", " + str(m[A[i]])
print ("A:", strA)

strB = str(m[B[0][0]])
for j in range(8):
    for i in range(9):
        if j == 0 and i == 0:
            continue
        strB = strB + ", " + str(m[B[j][i]])
print ("B:", strB)
