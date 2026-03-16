"""
Runs TC.jl with the given parameters
"""

Pkg.develop(path="/home/jbenjami/clima_Research_Schneider/CliMA/TurbulenceConvection.jl") # use local version
using TurbulenceConvection

function run_model(tau_func::Function, tau_params::Namedtuple)
"""

"""


tau_func = tau_func(tau_params..., x )