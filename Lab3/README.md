# Environment setting for simulation
There are two ways to simulate:
## CLI
```
git clone git@github.com:dqrengg/SoC_Laboratory.git
cd $PATH/Lab3              # should enter the downloaded directory
make                       # start simulation
gtkwave ./waveform/fir.vcd # open the waveform file
```
## Vivado GUI
1. Create a new project
2. Add design source: `fir.v`
3. Add simulation sources: `fir_tb.v` and `bram11.v`
4. Modify the dataset paths in `fir_tb.v`
5. Run behavioral simualtion
