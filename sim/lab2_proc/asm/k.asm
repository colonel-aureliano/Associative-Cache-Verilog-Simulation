csrr x1, mngr2proc < 0x2000
sw x1, 0(x1)
lw x3, 0(x1)
csrw proc2mngr, x3 > 0x2000
addi x3, x3, 1

      #data section
   .data
   .word 5000
   .word 5000
   .word 5000