    .text
    .globl _start

_start:
    li  t0, 10          # t0 = count (10)
    li  t1, 1           # t1 = a
    li  t2, 1           # t2 = b
    li  t3, 0           # t3 = i
    li  t4, 0x100       # t4 = memory pointer

loop:
    beq t3, t0, end     # if i == count -> end

    sw  t1, 0(t4)       # store a

    add t5, t1, t2      # t5 = a + b
    mv  t1, t2          # a = b
    mv  t2, t5          # b = t5

    addi t4, t4, 4      # pointer += 4
    addi t3, t3, 1      # i++

    j loop

hang:
    j hang              # infinite loop