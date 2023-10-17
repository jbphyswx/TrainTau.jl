# Note the depot path we're suing for this is ~/.julia not the same as the one we want for single_column_test.jl at ${CLIMA}/.julia_depot
using Pkg
using Dates
using DataStructures


function run_all_SOCRATES(;tau_weights=nothing, sysimage=false, truth=nothing, forcing_type="obs_data", kwargs...)
    # @show(kwargs)
    ## ================================================================================================================ ##
    rebuild = false # whether to run the rebuild job (please change to a ci argument this is kiling me)

    # kwargs = Dict(kwargs) # can seem to access inside otherwise

    if rebuild
        slurm_submit(rebuild=rebuild) # from slurm_submit.jl 
        exit() # don't run anything else if calle rebuild
    end
    ## ================================================================================================================ ##

    datetime_stamp = Dates.format(Dates.now(),"yyyy_mm_dd__HHMM_SS") # save here so they all get the same time

    # these will all go into the same dateteime folder like they were one long list of setups, and since different setups don't get merged in my processing routinern (these arent compatible in z) it should be ok for now!
    job_IDs = Dict()
    out_dirs = Dict()


    flight_numbers = [1,9,10,11,12,13]
    # flight_numbers = [9,13] # testing
    # t_max=100 # testing
    # t_max = 7200 # testing
    # t_max = 3600*6 # longer run
    t_max = 3600*14 # full run...
    # forcing_type = "ERA5_data"
    # forcing_type = "obs_data" # presumably we should only be running one of these... cause the losses are aggregated...

    
    for flight_number in flight_numbers
        case_name = "SOCRATES_RF"*string(flight_number,pad=2)*"_"*forcing_type

        # combined eq and one noneq default tau
        # setup_args_heirarchy = DataStructures.OrderedDict{Int,DataStructures.OrderedDict}(  # quick test
        # -1 => DataStructures.OrderedDict{String,Any}( "dtime" => [datetime_stamp], "skip_tests" => [true], "user_aux" => [(;tau_weights="\\\"" * tau_weights * "\\\"" )] ), # weight up here so don't go in name, escape so file can survive as string
        # 0  => DataStructures.OrderedDict{String,Any}( "case" => [case_name], "moisture_model" => ["nonequilibrium",], "precipitation_model" => ["clima_1m"], "sgs" => ["mean"], "dt" => [.5], "t_max" => [t_max]), # can also be ["adapt"] for adaptive timestep
        # 1  => DataStructures.OrderedDict{String,Any}( "user_args" => [(;use_ramp=false, use_supersat=true)] )
        # )

        # @show(kwargs)
        output_root = (:output_root in keys(kwargs)) ? kwargs[:output_root] : error("test") #Research_Schneider*"CliMa/Data/single_column/sensitivity/"*datetime_stamp*"/"


        # # Non_Eq explorer
        # setup_args_heirarchy = DataStructures.OrderedDict{Int,DataStructures.OrderedDict}(  # quick test, add output_root to force all our runs into one folder for storage (maybe this will break sumn later?)
        # -1 => DataStructures.OrderedDict{String,Any}( "dtime" => [datetime_stamp], "skip_tests" => [true], "user_aux" => [(;tau_weights=tau_weights )], "output_root" => [output_root]), # weight up here so don't go in name, escape so file can survive as string
        # 0  => DataStructures.OrderedDict{String,Any}( "case" => [case_name], "moisture_model" => ["nonequilibrium",], "precipitation_model" => ["clima_1m"], "sgs" => ["mean"], "dt" => [.5], "t_max" => [t_max], ), # can also be ["adapt"] for adaptive timestep
        # 1  => DataStructures.OrderedDict{String,Any}( "user_args" => [(;use_ramp=false, use_supersat=true)] )
        # )


        # Eq comparison w/ ramp
        setup_args_heirarchy = DataStructures.OrderedDict{Int,DataStructures.OrderedDict}(  # quick test, add output_root to force all our runs into one folder for storage (maybe this will break sumn later?)
        -1 => DataStructures.OrderedDict{String,Any}( "dtime" => [datetime_stamp], "skip_tests" => [true], "user_aux" => [(;)], "output_root" => [output_root]), # weight up here so don't go in name, escape so file can survive as string
        0  => DataStructures.OrderedDict{String,Any}( "case" => [case_name], "moisture_model" => ["equilibrium",], "precipitation_model" => ["clima_1m"], "sgs" => ["mean"], "dt" => [.5], "t_max" => [t_max], ), # can also be ["adapt"] for adaptive timestep
        1  => DataStructures.OrderedDict{String,Any}( "user_args" => [(;use_ramp=true, use_supersat=false)] )
        )


        # # force w/ real N_L, let N_I vary I guess (N_0 has format (; z, values) for each flight number), get N_0 from kwargs...
        # truth = load_truth()
        # N_0 = Dict( flight_number => truth[flight_number]["N_L"] for flight_number in flight_numbers ) # truth should be already loaded in values, z form from loss_socrates.jl
        # setup_args_heirarchy = DataStructures.OrderedDict{Int,DataStructures.OrderedDict}(  # quick test, add output_root to force all our runs into one folder for storage (maybe this will break sumn later?)
        # -1 => DataStructures.OrderedDict{String,Any}( "dtime" => [datetime_stamp], "skip_tests" => [true], "user_aux" => [(;N_0=N_0[flight_number])], "output_root" => [output_root]), # weight up here so don't go in name, escape so file can survive as string
        # 0  => DataStructures.OrderedDict{String,Any}( "case" => [case_name], "moisture_model" => ["nonequilibrium",], "precipitation_model" => ["clima_1m"], "sgs" => ["mean"], "dt" => [.5], "t_max" => [t_max], ), # can also be ["adapt"] for adaptive timestep
        # 1  => DataStructures.OrderedDict{String,Any}( "tau_sub_dep" =>  0 .^ range(0.3,5,10) , "user_args" => [(;use_ramp=false, use_supersat=true)] )
        # )

        ## ================================================================================================================ ##
        custom_filters = []
        job_ID, outdir = slurm_submit(setup_args_heirarchy=setup_args_heirarchy, custom_filters=custom_filters, rebuild=rebuild,sysimage=sysimage) # from SLURM_submit_SOCRATES.jl
        @show(job_ID, outdir)
        job_IDs[flight_number]  = job_ID[1]
        out_dirs[flight_number] = outdir[1]
        ## ================================================================================================================ ##
    end

    pending_jobs = collect(values(job_IDs)) # get values, convert to vector
    # @show(typeof(pending_jobs))
    iter=0
    while length(pending_jobs) > 0
        iter += 1
        sleep(1) # so this is paced...
        for job_ID in pending_jobs
            state_table = sacct(["--format=JobID,State", "--allocations"]) # not sure what "--allocations" is but simon used it
            if string(job_ID) in state_table[:,"JobID"]
                job_state   = state_table[state_table.JobID .== string(job_ID),"State"][1]  # extract the state from the table
                if job_state == "COMPLETED" # FROM SLURMTOOLS.JL
                    deleteat!(pending_jobs, findfirst(x->x==job_ID,pending_jobs))
                    @info(string(job_ID)*" "*job_state)
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


    # at the end return the output data from the runs
    output_data = Dict()
    for flight_number in flight_numbers
        case_name = "SOCRATES_RF"*string(flight_number,pad=2)*"_"*forcing_type
        output_path                = out_dirs[flight_number] * "Output."*case_name*".out/stats/Stats."*case_name*".nc" # could try Glob.jl, see https://discourse.julialang.org/t/rdir-search-recursive-for-files-with-a-given-name-pattern/75605/20
        if isfile(output_path)
            output_data[flight_number] = NCDatasets.Dataset(output_path,"r") # should I pull q_l, q_i here?
        else
            @warn("Output at "*output_path*" does not exist, leaving key for "*string(flight_number)*" empty")
        end
    end

    return output_data
end



