"""

"""

# using Flux (how do I train w/ unlabeled data? all i know is the right output...)
using Optim


# function trainFlux()
#     model = Chain(
#         Dense(2 => 3, tanh),   # activation function inside layer
#         BatchNorm(3),
#         Dense(3 => 2),
#         softmax) |> gpu        # move model to GPU, if available
        


#     # Initialize Weights
#     w = FT.([10,10])


#     # Run Model, Update Weights

#     loss(w) = SOCRATES_loss(run_all_SOCRATES(;tau_weights=w->tau2(w=w)))


#     optim = Flux.setup(Adam(), model)
#     @showprogress for epoch in 1:10
#         # Flux.train!(loss , model, w, optim)
#         Flux.train!(loss , params(model), w, optim)

#     end

#     return w
# end


function trainOptim(;output_file="training_log.out",sysimage=true)

    # IO_filestream =  open(output_file,"a")


    # Initialize Weights
    w = FT.([10,10])

    # doesn't work can't deserialize
    # temp_name = tempname() # serialize so can be unpacked from string later
    # @show(temp_name)
    # serialize(temp_name, w -> TrainTau.tau2(w))
    # @show(deserialize(temp_name))

    # optimize

    # can we request node and then keep sending the jobs to the same nodes? make system image on first iteration and then reuse... (or one node many processes and keep sending the jobs to the same processes...)

    # loss(w) = SOCRATES_loss(run_all_SOCRATES(;tau_weights = w) ) # raw values
    loss(w) = SOCRATES_loss(run_all_SOCRATES(;tau_weights = log10.(w), sysimage=sysimage )) # passing these funcs won't work cause we have to turn them into trings and back again

    @info("Optimizing beginning")
    w = optimize(loss,w; show_every=1, iterations=5)


    # write(IO_filestream, w); # not sure how to log every iteration...


    return w
end



# function grid_search_optimize(;output_file="grid_search_log.out",sysimage=false)

#     # using Distributed # could try add_procs and stuff and pmap to get this to work? seems to not be going over well rn...


#     # Instead we'll try to run a completely different slurm script for each of these...

#     # IO_filestream =  open(output_file,"a")


#     # Initialize Weights
#     tau = (;liq=range(0,5,10), ice=range(0,5,10)) # log space weights

#     @show(tau)

#     # loss = [SOCRATES_loss(run_all_SOCRATES(;tau_weights = [tau_liq,tau_ice])) for tau_liq in tau.liq for tau_ice in tau.ice]

#     min_loss, min_idx = findmin(loss)

#     return (;liq=10^tau.liq[min_idx[1]], ice=10^tau.ice[min_idx[2]]), min_loss, loss


# end