#!/bin/bash                                                                                                                    
#SBATCH --job-name=SBATCH_SCORATES_GRID_optimize
#SBATCH --output=/home/jbenjami/Research_Schneider/CliMa/TrainTau.jl/sbatch_grid_optimize.out
#SBATCH --nodes=1
#SBATCH --time=48:00:00
#SBATCH --mail-user=jbenjami@caltech.edu
#SBATCH --mail-type=ALL
#SBATCH --ntasks=1
#SBATCH --gres=gpu:1
#SBATCH --ntasks-per-node=1


module load julia/1.8.5
julia --project=/home/jbenjami/Research_Schneider/CliMa/TrainTau.jl/ -e 'include("/home/jbenjami/Research_Schneider/CliMa/TrainTau.jl/src/TrainTau.jl");  TrainTau.grid_search_optimize();'



