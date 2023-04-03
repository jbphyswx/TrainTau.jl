#!/usr/bin/env sh
#SBATCH --job-name slurm_parallel_test
#SBATCH --ntasks 100
#SBATCH --nodes 10
#SBATCH --cpus-per-task=1
#SBATCH --time=05:59:00
#SBATCH -o %x-%j.out
#SBATCH --mem 10GB
#SBATCH --mail-user jbenjami@caltech.edu
#=
srun julia $(scontrol show job $SLURM_JOBID | awk -F= '/Command=/{print $2}')
exit
# =#


# using ClusterManagers # may need to `unset SLURM_CPU_BIND` first, see https://bugs.schedmd.com/show_bug.cgi?id=14298#c1
using Mmap

# addprocs_slurm(10; nodes=10, topology=:master_worker)
# addprocs_slurm(10)

# addprocs_slurm( parse(Int, ENV["SLURM_NTASKS"]); topology=:master_worker)


function grid_search_optimize(;output_save_path=nothing,sysimage=false, save=true)

    # using Distributed # could try add_procs and stuff and pmap to get this to work? seems to not be going over well rn...


    # Instead we'll try to run a completely different slurm script for each of these...



    # Initialize Weights
    res = 2 # test
    res = 10
    tau = (;liq=range(0.3,5,res), ice=range(0.3,5,res)) # log space weights
    # tau = (;liq=[1], ice=[1]) # log space weights EQUIL 

    # forcing_type = "ERA5_data"
    forcing_type = "obs_data" # presumably we should only be running one of these... cause the losses are aggregated...


    sz_tau = (x->size(x)[1]).(values(tau)) 


    # tmp_file = tempname() # THIS DOESNT WORK CAUSE TMP IS NOT SHARED ACROSS  NODES
    tmp_file     = package_dir*"/."*lstrip(tempname(),'/') # just put tmpfile in pkgdir
    tmp_file_dir = package_dir*"/."*lstrip(tempname(),'/') # just put tmpfile in pkgdir

    dir_array = fill("",sz_tau)

    mkpath(dirname(tmp_file)) # make path if doesn't exist
    @info("tmpfile is :"*tmp_file)

    io = open(tmp_file, "w+");
    loss_array = mmap(io, Matrix{Float64}, sz_tau);
    loss_array .= NaN # fill w/ NaN (helps in case of failures too)
    Mmap.sync!(loss_array)
    close(io)

    # io = open(tmp_file_dir, "w+"); # doesn't work cause of mmap problems
    # dir_array = mmap(io, Matrix{Vector{UInt8}}, sz_tau); # use UInt8 to mmmap, see https://discourse.julialang.org/t/how-to-mmap-a-string/39291
    # dir_array .= Vector{UInt8}("") # fill w/ NaN (helps in case of failures too)
    # Mmap.sync!(dir_array)
    # close(io)

    datetime_stamp = Dates.format(Dates.now(),"yyyy_mm_dd__HHMM_SS") # save here so they all get the same time
    @show(datetime_stamp)

    if isnothing(output_save_path)
        output_save_path = Research_Schneider*"CliMa/Data/single_column/sensitivity/"*datetime_stamp*"/"*"grid_search_log.out"
        output_save_path_pkl = Research_Schneider*"CliMa/Data/single_column/sensitivity/"*datetime_stamp*"/"*"grid_search_log.out.pkl"

        @info("output_save_path: "*output_save_path)
    end

    include_path = joinpath(package_dir, "src", "TrainTau.jl")

    # iterate functions

    pending_jobs = []
    job_limit = 20
    # job_limit = 15

    # job_limit = 5
    for (i,tau_liq)=enumerate(tau.liq), (j,tau_ice)=enumerate(tau.ice)
        iter=0
        while length(pending_jobs) >= job_limit # if over job limit, just monitor
            iter += 1
            sleep(1) # so this is paced...
            for job_ID in pending_jobs
                state_table = sacct(["--format=JobID,State", "--allocations"]) # not sure what "--allocations" is but simon used it
                if string(job_ID) in state_table[:,"JobID"]
                    job_state   = state_table[state_table.JobID .== string(job_ID),"State"][1]  # extract the state from the table
                    if job_state == "COMPLETED" # FROM SLURMTOOLS.JL
                        deleteat!(pending_jobs, findfirst(x->x==job_ID,pending_jobs))
                    elseif job_state ∉ ["RUNNING", "PENDING"]
                        @warn(string(job_ID)*" "*job_state)
                        deleteat!(pending_jobs, findfirst(x->x==job_ID,pending_jobs))
                    end
                else
                    @warn(string(job_ID)*" not fully submitted yet")
                    nothing # job hasn't started yet
                end
            end
        end

        # once under job limit, add the job
        # @show(i,j, Dates.format(Dates.now(),"yyyy_mm_dd__HHMM_SS"))
        # sleep(1) # make sure they get a different second in their job... since we dont use job_array_id in filename...
        # open later w/ r+ so as to not overwrite the old stuff, w+ opens a new array, r+	read, write	read = true, write = true


        # maybe could do with expressions? say we pass in weights=(;a,b,c) and then evaluate eval(expr), expr = :(w^a + b*T^c) or something... will try on sampo I guess... will let tau_weights = (;weights, func_expr)
        tau_weights = (; liq = (; liq_params = (;log10_tau_liq  = tau_liq), func_expr = :(10 .^ liq_params.log10_tau_liq) ), ice = (; ice_params = (;log10_tau_ice  = tau_ice), func_expr = :(10 .^ ice_params.log10_tau_ice) ) ) # expression for tau

        # testing extra quotes from Base.shell_escape_posixly()
        # tau_weights = "'(; liq = (; liq_params = (;log10_tau_liq  = $tau_liq), func_expr = :(10 .^ liq_params.log10_tau_liq) ), ice = (; ice_params = (;log10_tau_ice  = $tau_ice), func_expr = :(10 .^ ice_params.log10_tau_ice) ) )'" # expression for tau, test string version


        tau_params = (;log10_tau_liq=tau_liq,log10_tau_ice=tau_ice) # for easy string interpolation below...
        output_root = Research_Schneider*"CliMa/Data/single_column/sensitivity/"*datetime_stamp*"/" *  rstrip(join([string(key)*"-"*string(val)*"__" for (key,val) in zip(keys(tau_params), tau_params)]),'_') *"/" # problematic for this represenation with parentheses in expr

        @show(output_root)

        # array version for tau_weights i think doesnt need the extra quotes (also for string maybe?)
        job_ID = sbatch_julia_expr("using Pkg; Pkg.activate(\\\"$package_dir\\\");include(\\\"$include_path\\\");loss = TrainTau.SOCRATES_loss(TrainTau.run_all_SOCRATES(;tau_weights = $tau_weights, output_root=\\\"$output_root\\\", forcing_type=\\\"$forcing_type\\\" )); @show(\\\"Writing loss \$loss to [$i,$j] in output array at $tmp_file.\\\"); @show(loss);
        using Mmap; io = open(\\\"$tmp_file\\\", \\\"r+\\\"); loss_array = mmap(io, Matrix{Float64}, $sz_tau); loss_array[$i,$j]=loss; @show(loss_array); Mmap.sync!(loss_array); close(io); ") # this has a problem where these jobs fill the queue and don't allow the actual runs to run, can we batch smaller somehow? maybe limit by # of pending jobs?

        # # string version for tau_weights i think doesnt need the extra quotes (in a list so it doesnt get parsed into a long array)
        # job_ID = sbatch_julia_expr("using Pkg; Pkg.activate(\\\"$package_dir\\\");include(\\\"$include_path\\\");loss = TrainTau.SOCRATES_loss(TrainTau.run_all_SOCRATES(;tau_weights = \"\"\"$tau_weights\"\"\", output_root=\\\"$output_root\\\" )); @show(\\\"Writing loss \$loss to [$i,$j] in output array at $tmp_file.\\\"); @show(loss);
        # using Mmap; io = open(\\\"$tmp_file\\\", \\\"r+\\\"); loss_array = mmap(io, Matrix{Float64}, $sz_tau); loss_array[$i,$j]=loss; @show(loss_array); Mmap.sync!(loss_array); close(io); ") # this has a problem where these jobs fill the queue and don't allow the actual runs to run, can we batch smaller somehow? maybe limit by # of pending jobs?
        
        # # # named tuple version for tau_weights i think needs the extra quotes
        # job_ID = sbatch_julia_expr("using Pkg; Pkg.activate(\\\"$package_dir\\\");include(\\\"$include_path\\\");loss = TrainTau.SOCRATES_loss(TrainTau.run_all_SOCRATES(;tau_weights = \\\"$tau_weights\\\", output_root=\\\"$output_root\\\" )); @show(\\\"Writing loss \$loss to [$i,$j] in output array at $tmp_file.\\\"); @show(loss);
        # using Mmap; io = open(\\\"$tmp_file\\\", \\\"r+\\\"); loss_array = mmap(io, Matrix{Float64}, $sz_tau); loss_array[$i,$j]=loss; @show(loss_array); Mmap.sync!(loss_array); close(io); ") # this has a problem where these jobs fill the queue and don't allow the actual runs to run, can we batch smaller somehow? maybe limit by # of pending jobs?
        
        # # quick test func
        # job_ID = sbatch_julia_expr("using Pkg; Pkg.activate(\\\"$package_dir\\\");include(\\\"$include_path\\\");loss = rand();                                                                                    @show(\\\"Writing loss \$loss to [$i,$j] in output array at $tmp_file.\\\"); @show(loss);
        # using Mmap; io = open(\\\"$tmp_file\\\", \\\"r+\\\"); loss_array = mmap(io, Matrix{Float64}, $sz_tau); loss_array[$i,$j]=loss; @show(loss_array); Mmap.sync!(loss_array); close(io)") # this has a problem where these jobs fill the queue and don't allow the actual runs to run, can we batch smaller somehow? maybe limit by # of pending jobs?
        
        dir_array[i,j] = strip(join([string(key)*"-"*string(val)*"__" for (key,val) in zip(keys(tau_params), (tau_liq, tau_ice))]),'_') *"/"
        @show(dir_array)

        push!(pending_jobs, job_ID)
    end

    # @show(tau_params)


    iter=0
    while length(pending_jobs) > 0 # wait for remaining jobs
        iter += 1
        sleep(1) # so this is paced...
        for job_ID in pending_jobs
            state_table = sacct(["--format=JobID,State", "--allocations"]) # not sure what "--allocations" is but simon used it
            if string(job_ID) in state_table[:,"JobID"]
                job_state   = state_table[state_table.JobID .== string(job_ID),"State"][1]  # extract the state from the table
                if job_state == "COMPLETED" # FROM SLURMTOOLS.JL
                    deleteat!(pending_jobs, findfirst(x->x==job_ID,pending_jobs))
                elseif job_state ∉ ["RUNNING", "PENDING"]
                    @warn(string(job_ID)*" "*job_state)
                    deleteat!(pending_jobs, findfirst(x->x==job_ID,pending_jobs))
                end
            else
                @warn(string(job_ID)*" not fully submitted yet")
                nothing # job hasn't started yet
            end
        end
        if mod(iter,10) == 0
            @show(pending_jobs)
        end
    end


    io = open(tmp_file, "r");
    loss_array = mmap(io, Matrix{Float64}, sz_tau);
    close(io)
    rm(tmp_file)

    # dir_array = ((tau_liq, tau_ice) -> ((tau_weights)->Research_Schneider*"CliMa/Data/single_column/sensitivity/"*datetime_stamp*"/" *  rstrip(join([string(key)*"-"*string(val)*"__" for (key,val) in zip(keys(tau_weights), tau_weights)]),'_') *"/")((;liq=tau_liq,ice=tau_ice))).(tau.liq, tau.ice')
    # dir_array = ((tau_liq, tau_ice) -> ((tau_weights)->rstrip(join([string(key)*"-"*string(val)*"__" for (key,val) in zip(keys(tau_weights), tau_weights)]),'_') *"/")((;liq=tau_liq,ice=tau_ice))).(tau.liq, tau.ice') # i think we just need folder array but weve named it now anyway so could reconstruct but mayb this will be useful still idk...

    # dir_array = ((tau_liq, tau_ice) -> ((tau_weights)->rstrip(join([string(key)*"-"*string(val)*"__" for (key,val) in zip(keys(tau_weights), tau_weights)]),'_') *"/")((;liq=tau_liq,ice=tau_ice))).(tau.liq, tau.ice') # i think we just need folder array but weve named it now anyway so could reconstruct but mayb this will be useful still idk...

    # dir_array = ((tau_liq, tau_ice) -> ((tau_weights)->rstrip(join([string(key)*"-"*string(val)*"__" for (key,val) in zip(keys(tau_params), tau_weights)]),'_') *"/")((;liq=tau_liq,ice=tau_ice))).(tau.liq, tau.ice') # use what the folders where actually named with (tau_params)
    # @show(tau_params)
    # dir_array = ((tau_liq, tau_ice;tau_params) -> ((tau_weights;tau_params)->rstrip(join([string(key)*"-"*string(val)*"__" for (key,val) in zip(keys(tau_params), tau_weights)]),'_') *"/")((tau_liq, tau_ice);tau_params=tau_params)).(tau.liq, tau.ice'; tau_params=tau_params) # use what the folders where actually named with (tau_params)

    out = (;loss_array, dir_array, tau)
    
    if save
        JLD2.save_object(output_save_path, out)
        out_pickle = Dict(string(k)=>v for (k,v) in pairs(out)); out_pickle["tau"] = Dict(string(k)=>collect(v) for (k,v) in pairs(out_pickle["tau"])) # remove symbols for strings

        pickle = pyimport("pickle") # pickle and serializaiton didn't work so use this
        f = open(output_save_path_pkl,"w+")
        pickle.dump(PyObject(out_pickle),f )
        close(f)
    end

    return out

    # loss = pmap((tau_liq,tau_ice)->SOCRATES_loss(run_all_SOCRATES(;tau_weights = [tau_liq,tau_ice])) , tau_liq in tau.liq , tau_ice in tau.ice)


end

# grid_search_optimize()







# VERBOSE = false

# "workers() but excluding master"
# getworkers() = filter(i -> i != 1, workers())

# function start_up_workers(ENV::Base.EnvDict; nprocs = Sys.CPU_THREADS)
#     # send primitives to workers
#     oldworkers = getworkers()
#     println_time_flush("removing workers $oldworkers")
#     rmprocs(oldworkers)
#     flush(stdout)
    
#     if "SLURM_JOBID" in keys(ENV)
#         num_cpus_to_request =
#         println_time_flush("requesting $(num_cpus_to_request) cpus from slurm.")
#         pids = addprocs(SlurmManager(; verbose=VERBOSE); exeflags = "--project=$(Base.active_project())", topology=:master_worker)
#     else
#         cputhrds = Sys.CPU_THREADS
#         cputhrds < nprocs && @warn "using nprocs = $cputhrds < $nprocs specified"
#         pids = addprocs(min(nprocs, cputhrds); exeflags = "--project=$(Base.active_project())", topology=:master_worker)
#     end
#     println_time_flush("Workers added: $pids")
#     return pids
# end

# function println_time_flush(str)
#     println(Dates.format(now(), "HH:MM:SS   ") * str)
#     flush(stdout)
# end

# hellostring() = "hello from $(myid()):$(gethostname())"