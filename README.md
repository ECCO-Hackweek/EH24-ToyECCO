# Toy ECCO

## Introduction

Toy version of `ECCO` estimation problem in `Julia`, and benchmarking of `AD` (Algorithmic Differentiation) tools including `Enzyme.jl`, `Tapenade`, `Jax`, `ForwardDiff.jl`, and `Zygote.jl`. The `Optim.jl` package is used for the optimization problem.

### Collaborators

Shreyas Gaikwad, Max Trostel, Ellen Davenport, Gaël Forget

### The problem

AD tools are hard to compare across different languages and algorithms because they all require slightly different implementation. This is an attempt to get some basic examples working with comparisons across languages (Python, Fortran, Julia) and open source AD tools (Enzyme, PyTorch, JAX, Tapenade).

## Content

### Summary slide

🚀🚀🚀 `report/Toy ECCO Slide.pdf` 🚀🚀🚀

### `notebooks` and `scripts` folders

- [bulkformulae_optimization.ipynb](https://github.dev/ECCO-Hackweek/EH24-ToyECCO/blob/main/notebooks/bulkformulae_optimization.ipynb)
- [L96.ipynb](https://github.dev/ECCO-Hackweek/EH24-ToyECCO/blob/main/notebooks/L96.ipynb)
- [L96_torch_jax.ipynb](https://github.dev/ECCO-Hackweek/EH24-ToyECCO/blob/main/notebooks/L96_torch_jax.ipynb)
- [mountain_glacier.jl](https://github.dev/ECCO-Hackweek/EH24-ToyECCO/blob/main/scripts/mountain_glacier.jl)
- [mountain_glacier_f90_model](https://github.dev/ECCO-Hackweek/EH24-ToyECCO/blob/main/scripts/mountain_glacier_f90_model)
- [mountain_glacier_torch_jax.ipynb](https://github.dev/ECCO-Hackweek/EH24-ToyECCO/blob/main/scripts/mountain_glacier_torch_jax.ipynb)
- [ForwardDiff_Zygote_Enzyme.ipynb](https://github.dev/ECCO-Hackweek/EH24-ToyECCO/blob/main/notebooks/ForwardDiff_Zygote_Enzyme.ipynb)
- [optim_and_enzyme.ipynb](https://github.dev/ECCO-Hackweek/EH24-ToyECCO/blob/main/notebooks/optim_and_enzyme.ipynb)

### environment files 

- [environment.yml](https://github.dev/ECCO-Hackweek/EH24-ToyECCO/blob/main/environment.yml)
- [Project.toml](https://github.dev/ECCO-Hackweek/EH24-ToyECCO/blob/main/Project.toml)
- [Manifest.toml](https://github.dev/ECCO-Hackweek/EH24-ToyECCO/blob/main/Manifest.toml)
