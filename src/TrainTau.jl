module TrainTau

using Pkg
Pkg.develop(path="/home/jbenjami/bin/git/SlurmTools.jl")
Pkg.develop(path="/home/jbenjami/Research_Schneider/CliMa/TurbulenceConvection.jl")

using Serialization
using SlurmTools
using NCDatasets
using Dierckx
using LinearAlgebra
using Random
using JLD2
using Pickle
using Serialization
using PyCall
using HDF5

# using Flux
using Optim
using Statistics
using ProgressMeter

FT = Float64

package_dir = dirname(@__DIR__)# parent of parent...

include("SOCRATES/SLURM_submit_SOCRATES.jl")
include("SOCRATES/run_all_SOCRATES.jl")
include("SOCRATES/loss_SOCRATES.jl")
include("SOCRATES/SOCRATES_Workflow.jl")
include("SOCRATES/slurm_parallel_test.jl")
include("SOCRATES/reconstruct_loss.jl")
end # module TrainTau
