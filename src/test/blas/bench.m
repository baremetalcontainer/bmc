n=1600;
A=rand(n);
B=rand(n);
tic();
C=A*B;
t=toc();
GFLOPS=2*n^3/t*1e-9;
GFLOPS
