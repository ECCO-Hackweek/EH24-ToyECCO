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

### `notebooks/` folder

- `ForwardDiff_Zygote_Enzyme.ipynb`
- `L96.ipynb`
- `L96_torch_jax.ipynb`
- `bulkformulae_optimization.ipynb`
- `optim_and_enzyme.ipynb`


### `scripts/` folder

- `mountain_glacier.jl`
- `mountain_glacier_f90_model`
- `mountain_glacier_torch_jax.ipynb`

### environment files 

- `Manifest.toml`
- `Project.toml`
- `environment.yml`
