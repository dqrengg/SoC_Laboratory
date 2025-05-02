# Lab 4-2

## Directory Structure

```
Lab4-2/
├─ src/
│  ├─ cvc-pdk/
│  ├─ firmware/
│  ├─ rtl/
│  ├─ testbench/counter_la_fir/
│  ├─ vip/
│  ├─ vivado/
├─ waveform/
├─ README.md
```

* all source code including testbench in `src`
* `waveform` only for reference, the final optimized version in `src/testbench/counter_la_fir/`

## Simulation

```sh
cd ./testbench/counter_la_fir/
source run_clean
source run_sim
```

* The `.hex` file loaded to flash in testbench is the manually modified version.
* You can change the file name to run original version
* Use waveform configuration `signals.gtkw` for debugging
