# Multi contexts tests

First of all you should buid [kernel](https://github.com/onlyoneofme/damon-multi-contexts) with `DAMON_SYSFS` enabled and run it in `QEMU` or on your host machine and only then trying this, otherwise you're expected to get `-EINVAL` or so during configuring `kdamond`.

This repository contains few simple shell scripts that run `kdamond`, but use different setups, which are:
  - `run_one_targets.sh`   - sets up `kdamond` to run only one contexts with only one target (`masim` is used);
  - `run_many_targets.sh`  - sets up `kdamond` to run one context with many targets (number of targets can be configured inside the script, these targets are `masim` with special config);
  - `run_many_contexts.sh` - sets up `kdamond` to run many contexts with only one target per context (targets are the same as for `run_many_targets.sh`);

Actually all of these scripts just run `perf` and collects `damon:damon_aggregated` trace events, so output perf data is saved to `masim.data` and `masim.script` (output of the command `perf script` applied to `masim.data`).

To be able to visualize results I modified `damo` to support multiple contexts, so it can be used as usual (I targeted this support only for `record` and `report heats` commands, so not all functionality can be available). To visualize results from `masim.data` can use the following:

1. First, we need to check what we can report by using `report heats --guide`:
    ```
    # I assume you did 'git clone ... && cd damon-multi-contexts-tests/damo'
    # and run 'run_many_contexts.sh' script above
    $ sudo ./damo report heats --guide --input ../masim.data
    context_id:0 target_id:0
    time: 1642148209000-1671789768000 (29.642 s)
    region   0: 00000094151691976704-00000094152208547840 (492.641 MiB)
    region   1: 00000140116146257920-00000140116350914560 (195.176 MiB)
    region   2: 00000140728469610496-00000140728469745664 (132.000 KiB)
    context_id:1 target_id:0
    time: 1642148229000-1671789783000 (29.642 s)
    region   0: 00000093999059812352-00000094000005705728 (902.074 MiB)
    region   1: 00000140259018932224-00000140259127308288 (103.355 MiB)
    region   2: 00000140733565636608-00000140733565771776 (132.000 KiB)
    context_id:2 target_id:0
    time: 1642148253000-1671789802000 (29.642 s)
    region   0: 00000093838652059648-00000093839549644800 (856.004 MiB)
    region   1: 00000140242271076352-00000140242475356160 (194.816 MiB)
    region   2: 00000140723986927616-00000140723987062784 (132.000 KiB)
    ```
    Now we can visualize what `kdamond` collected.

2. Let's use `--plot_ascii` for this:
   ```
   $ sudo ./damo report heats --cid 0 --plot_ascii --input ../masim.data --address_range 00000140116146257920 00000140116350914560
   ```
   ![damo report from masim zigzag config](https://github.com/onlyoneofme/damon-multi-contexts-tests/blob/main/images/masim-zigzag.png)

I added `--cid` option to `damo report heats` to be able to differentiate contexts. A user can also use `damo record $PID` or so to save `damon.data` and then use `damo report` on this data.
