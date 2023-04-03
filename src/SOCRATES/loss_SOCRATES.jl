using Dierckx
using LinearAlgebra

function pyinterp(x, xp, fp; FT=Float64)
    " adapted so outside of range returns NaN"
    # @show(x, xp, fp)

    T,elT = typeof(xp), eltype(xp)

    lims = extrema(xp)
    out  = convert.(FT, x)

    in_bounds = x .>= lims[1] .&& x .<= lims[2]
    spl = Dierckx.Spline1D(xp, fp; k = 1)

    out[in_bounds] = spl(vec(out[in_bounds]) )
    out[.!in_bounds] .= NaN
    return out
end

SOCRATES_truth_link = "https://caltech.box.com/shared/static/pwhfmx3hkjjii45gteoegpnfqkjplmgd.pickle" # On Box @ Research_Schneider/Projects/Microphysics # Remember to sync to SOCRATESSingleColumnForcings.jl (the small file)
SOCRATES_truth_jl_save_path = joinpath(package_dir, "SOCRATES_Truth_Data.jld2")

@info("Retrieving and Saving SOCRATES truth/verification Data") # need to uncomment to update data
using Pickle
SOCRATES_truth_save_path = joinpath(package_dir, "SOCRATES_Truth_Data.pickle")
SOCRATES_truth_data = download(SOCRATES_truth_link, SOCRATES_truth_save_path)
socrates_truth = Pickle.load(open(SOCRATES_truth_save_path); proto = 5)
JLD2.save_object(SOCRATES_truth_jl_save_path, socrates_truth)



function load_truth()
    # load the truth from the jld container...
    @info("constructing SOCRATES truth data container")
    SOCRATES_truth_data = JLD2.load_object(SOCRATES_truth_jl_save_path)

    # @info(SOCRATES_truth_data[13].keys)

    truth = Dict()
    for flight_number = [1, 9, 10, 11, 12 ,13]
        truth[flight_number] = Dict()
        for var in ["ql_mean","qi_mean","N_L"] # could add qc or updrafts or such later... idk...
            truth[flight_number][var] = (; values = SOCRATES_truth_data[flight_number][var]["values"], z =SOCRATES_truth_data[flight_number][var]["z"] )
        end
    end
    return truth
end
truth = load_truth() # save here for later use in loss

# function SOCRATES_loss(model_output; truth=truth, vars=["ql_mean","qi_mean"])
#     loss = 0
#     for (flight_number,model_output) in model_output
#         for var in vars
#             q = pyinterp(truth[flight_number]["zc"], model_output.group["profiles"]["zc"][:], model_output.group["profiles"][var][:,end][:])
#             loss  += norm(q .- truth[flight_number][var])
#         end
#     end
#     @show(loss)
#     return loss
# end

function SOCRATES_loss(model_outputs; truth=truth, vars=["ql_mean","qi_mean"])
    loss = 0
    n = 0
    for (flight_number,model_output) in model_outputs # automatically will overlook missing values
        for var in vars
            if length( truth[flight_number][var].z ) > 0 # can only interp if len > 0
                q = pyinterp(truth[flight_number][var].z, model_output.group["profiles"]["zc"][:], model_output.group["profiles"][var][:,end][:]) # should we use end? truth array is averaged so doesn't have time info anymore so hopefully our sims are steady-ish state? ( how to exclude crashes that still have valid netcdf?)
                q_truth = truth[flight_number][var].values
                valid = (!isnan).(q) # where the interpolation was valid (no extrapolation, theyre but on same grid now)
                n     += sum(valid)
                loss  += norm(q[valid] .- truth[flight_number][var].values[valid])
            end
        end
    end
    loss = loss/n # normalize by # of obs
    @show(loss)
    return loss
end