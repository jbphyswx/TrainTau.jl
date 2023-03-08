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

SOCRATES_truth_link = "https://caltech.box.com/shared/static/pwhfmx3hkjjii45gteoegpnfqkjplmgd.pickle"
SOCRATES_truth_jl_save_path = joinpath(package_dir, "SOCRATES_Truth_Data.jld2")

# @info("Retrieving and Saving SOCRATES truth/verification Data")
# using Pickle
# SOCRATES_truth_save_path = joinpath(package_dir, "SOCRATES_Truth_Data.pickle")
# SOCRATES_truth_data = download(SOCRATES_truth_link, SOCRATES_truth_save_path)
# socrates_truth = Pickle.load(open(SOCRATES_truth_save_path); proto = 5)
# JLD2.save_object(SOCRATES_truth_jl_save_path, socrates_truth)

@info("constructing SOCRATES truth data container")
SOCRATES_truth_data = JLD2.load_object(SOCRATES_truth_jl_save_path)

truth = Dict()
for flight_number = [1, 9, 10, 11, 12 ,13]
    truth[flight_number] = Dict()
    for var in ["ql_mean","qi_mean"] # could add qc or updrafts or such later... idk...
        truth[flight_number][var] = (; values = SOCRATES_truth_data[flight_number][var]["values"], z =SOCRATES_truth_data[flight_number][var]["z"] )
    end
end

# truth[9] = Dict()

# truth[9]["ql_mean"] = [1.8803895e-03, 0.0000000e+00, 2.2557497e-06, 1.6112393e-06, 6.6681114e-06, 2.2107884e-06, 4.9198579e-06, 1.3289584e-05, 1.2257113e-05, 8.2958486e-06, 9.8279361e-06, 2.1024052e-05, 1.6743552e-05, 3.6347865e-05, 3.6873273e-05, 6.8661029e-05, 8.6761451e-05, 1.0372695e-04, 5.5313471e-05, 6.2740219e-05,
#          8.8620043e-05, 1.6365442e-04, 1.7657458e-04, 2.4630094e-04, 3.1644272e-04, 8.1669219e-05, 2.4085171e-05, 7.1768233e-07, 2.3333928e-06, 2.9973357e-06, 2.9620073e-06, 2.2866016e-06, 2.2152012e-06, 3.9847077e-06, 6.7834653e-06, 5.5473320e-06, 3.5234707e-06, 3.2037469e-06, 6.1370488e-06]


# truth[9]["qi_mean"] = [0.0000000e+00, 0.0000000e+00, 4.6517016e-08, 0.0000000e+00, 7.0091701e-06, 0.0000000e+00, 2.1916821e-07, 7.6217020e-07, 2.1377218e-07, 3.4573175e-05, 2.4878924e-05, 3.3202850e-06, 1.0341988e-05, 1.2560633e-04, 5.5605306e-05, 3.7759179e-05, 1.6688551e-05, 4.5022534e-06, 7.0094065e-06, 1.0708740e-05,
#          8.5277716e-06, 2.5508343e-05, 2.2246386e-06, 7.4990385e-06, 5.5144192e-06, 3.8745638e-06, 6.1450919e-07, 3.3556944e-09, 1.2782994e-07, 4.1500243e-07, 2.2222230e-07, 0.0000000e+00, 3.3667220e-09, 3.5483845e-07, 1.8076662e-08, 0.0000000e+00, 0.0000000e+00, 0.0000000e+00, 0.0000000e+00]

# truth[9]["zc"] = [ -65.1965,   29.4075,  229.1465,  338.6095,  367.507 ,  396.8575, 399.6445,  445.2945,  535.092 ,  645.6785,  795.6435,  963.32  ,1131.3105, 1306.075 , 1487.319 , 1670.349 , 1848.404 , 2020.816 , 2183.684 , 2347.208 , 2474.718 , 2553.4985, 2591.8135, 2620.9515,
#          2683.4915, 2789.9245, 2907.902 , 2954.3585, 2972.5245, 3056.228 , 3161.7335, 3201.333 , 3202.0875, 3297.607 , 3652.6465, 4198.364 , 4772.3765, 5332.2035, 5801.527 ]

# truth[13] = Dict()

# truth[13]["ql_mean"] =  [0.0000000e+00, 1.1251421e-07, 0.0000000e+00, 7.6544329e-06, 7.1712893e-06, 1.1655833e-05, 9.6207605e-06, 1.0671656e-05, 8.0058971e-06, 5.3638955e-06, 3.2559856e-05, 6.0089340e-05, 1.0914323e-04, 2.0368447e-04, 3.0156525e-04, 2.7675444e-04, 4.0539095e-04, 2.2329697e-04, 2.1828237e-04, 3.4612684e-05,
#          4.1947580e-05, 1.1814989e-05, 1.7148528e-06, 2.0947884e-05, 1.5797444e-06, 8.0756195e-07, 4.4335479e-07, 1.1515195e-06,  3.2526830e-07, 5.3525144e-07, 4.0825756e-07, 1.0184388e-06, 1.3248949e-06, 9.7485326e-06, 7.1796226e-06, 5.3580125e-06]
 
# truth[13]["qi_mean"]  = [0.0000000e+00, 0.0000000e+00, 0.0000000e+00, 0.0000000e+00,  0.0000000e+00, 2.2943823e-08, 1.6116519e-07, 5.2367432e-07, 3.1608552e-06, 2.4189180e-06, 5.4457778e-06, 4.8663715e-06, 6.1992832e-06, 3.6130514e-06, 5.8193109e-07, 4.4937478e-06, 2.8104696e-06, 1.0841031e-06, 2.6805355e-06, 2.4090987e-06,
# 1.8930587e-06, 2.6505113e-06, 1.4468668e-06, 2.5178415e-06, 7.2304522e-07, 9.8342218e-07, 4.2054813e-07, 1.3331631e-06, 7.4897457e-09, 4.1664691e-08, 4.9499107e-08, 2.7074179e-08, 2.9459329e-08, 2.6412636e-08, 2.3179837e-08, 1.7776074e-09]
        
# truth[13]["zc"] = [-8.9346500e+01,  2.5600000e-01,  7.4327500e+01,  8.2450000e+01, 8.6453000e+01,  9.1486000e+01,  1.1204950e+02,  1.6804900e+02, 2.6815200e+02,  3.8000750e+02,  4.9953400e+02,  6.2096900e+02, 7.2651800e+02,  8.0987300e+02,  8.5012950e+02,  8.9733950e+02,
# 9.4710650e+02,  9.7640850e+02,  1.0154210e+03,  1.0527905e+03, 1.0953645e+03,  1.1354420e+03,  1.1486505e+03,  1.1845890e+03, 1.2324385e+03,  1.2713680e+03,  1.3106780e+03,  1.3825955e+03, 1.4423635e+03,  1.4462675e+03,  1.4503695e+03,  1.4518620e+03, 1.4544720e+03,  2.0011510e+03,  3.4159305e+03,  5.1410640e+03]


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