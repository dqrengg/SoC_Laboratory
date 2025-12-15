# Lab Workload-optimized SoC

- [Documentation](https://hackmd.io/@dqrengg/B1w1zHlzZl)

## Directory Structure

```
Lab-wlos/
├─ src/
│  ├─ firmware/
│  ├─ rtl/
│  ├─ testbench/wlos/
│  ├─ vip/
├─ README.md
```

* All source code (including testbenches): `src/`
* User project: `src/rtl/user/`
* Firmware: `src/firmware/`
* Testbench: `src/testbench/wlos/`

## Simulation

* Running iverilog simulation
```sh
cd src/testbench/wlos/
source run_clean
source run_sim
```

<!-- * Use waveform configuration `signals.gtkw` for debugging-->
* To open the waveform file
```sh
gtkwave wlos.gtkw
```


