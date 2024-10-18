## Compilation

Just enter this directory on the terminal and type `make` to compile the executable `ad` that computes the gradient using 3 methods: finite differences, tangent linear mode, adjoint.

## Running the executable

Just the run the command `./ad` to run the executable and get the results

## Other notes

The direcotry `ADFirstAidKit` contains some Tapenade files and comes with the standard Tapenade tarball, you just copy this directory into any proejct where you want to use Tapenade and compile a few necessary files such as `adStack.c` and optionally, for binomial checkpointing `adBinomial.c`.

## More resources

Refer [here](https://sicopolis.readthedocs.io/en/latest/AD/tutorial_tapenade.html) and [here](https://ecco-hackweek.github.io/ecco-2024/tutorials/AD_tuts/tutorial_tapenade_mountain_glacier.html) for a more detailed introduction to each of the files and the mountain glacier model itself.
