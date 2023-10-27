# Note the depot path we're suing for this is ~/.julia not the same as the one we want for single_column_test.jl at ${CLIMA}/.julia_depot

## currently these are included in single_column_sensitivity_jobs.jl
# using Pkg
# using Random
# Pkg.add("DataStructures")
# using DataStructures

# Pkg.add("SlurmTools")
# Pkg.develop(path="/home/jbenjami/bin/git/SlurmTools.jl") # not sure what the right way to replace things is ... # for some reason this line causes the installation of everything clima related into main... no idea why... needed for rebuild?
# Pkg.build() # to get this slurmtools built in? otherwise we have to call activate to use it from TC.jl depots which is redundant with our local calls inside the runs...
# using SlurmTools
# Pkg.activate("/central/home/jbenjami/Research_Schneider/CliMa/TurbulenceConvection.jl/integration_tests/") # we need this to set an environment packages from that folder not in the main package, put after develop so that it isn't active when develop is called causing precompilation to fill up whatever environment we're in... (to do, move to rebuild only?) maybe it'll work fine from the activations in the bash calls... idk...



Research_Schneider = "/home/jbenjami/Research_Schneider/"
CLIMA=Research_Schneider*"CliMa/TurbulenceConvection.jl"
in_script=Research_Schneider*"CliMa/jobs/single_column/single_column_test.jl" # not sure if redundant w/ project, hopefully is aight

# use a dict for easy editing...     |      can also do stuff like #SBATCH --array=17-23
default_slurm_args = Dict{String,Any}(                                                                             
    "job-name"=>"single_column_test",
    "output"=>Research_Schneider*"CliMa/jobs/out/single_column_test.out",
    "nodes"=>"1",
    "mem"=>"10GB", # test cause some crashed in memory and charles doin in cmmit #1267
    "time"=>"05:59:00",
    "mail-user"=>"jbenjami@caltech.edu",
    "mail-type"=>"ALL",
    "ntasks"=>"1",
    "gres"=>"gpu:0",
    "ntasks-per-node"=>"1",
)

## ================================================================================================================ ##

function slurm_submit(;setup_args_heirarchy::AbstractDict=DataStructures.OrderedDict{String,Any}(), custom_filters::Any=[], rebuild=false, sysimage=false)
    """
    This should take a dictionary wit a heirarchy of args and submit as jobs to slurm

    # also accepts a list of custom filter fcns f(setup, full_setup, valid_setups(_no_undef), setup_args_heirarchy) that can run and filter the list of valid setups and returns true or false
    # edit so can call rebuild w/o the otehr arguments
    """

    print("hiiii")

    ## ================================================================================================================ ##
    bash_commands = [ # usin raw so we dont have to escape all the dollar signs and brackets
        "echo running bash commands",
        "CLIMA=$(CLIMA)",
        "set -euo pipefail", # kill the job if anything fails
        # "set -x", # echo script line by line as it runs it
        "module purge",
        "module load julia/1.9.3", # rely on bashrc doesnt work, we gotta update this everytime we update julia...
        "module load hdf5/1.10.1",
        "module load netcdf-c/4.6.1",
        "module load cuda/11.2",
        "module load openmpi/4.0.4_cuda-10.2",
        "module load cmake/3.10.2", # CUDA-aware MPI
        # "module load HDF5/1.8.19-mpich-3.2", # seems to be only sampo default
        # "module load netCDF/3.6.3-pgi-2017", # seems to be only sampo default
        # "module load openmpi/1.10.2/2017",  
        # "module load mpi/openmpi-x86_64",
        #
        raw"export JULIA_NUM_THREADS=${SLURM_CPUS_PER_TASK:=1}",
        # "export JULIA_DEPOT_PATH=$(CLIMA)/.julia_depot", # not sure why i commented this out, seems to lead to mpi binary has changed, please run pkg.build mpi...
        "export JULIA_DEPOT_PATH=$(CLIMA)/.julia_depot", # not sure why i commented this out, seems to lead to mpi binary has changed, please run pkg.build mpi...
        "export JULIA_MPI_BINARY=system", # does this cause a problem between nodes?
        "export JULIA_CUDA_USE_BINARYBUILDER=false",
        # "julia --project=$(CLIMA) -e 'using MPIPreferences; MPIPreferences.use_system_binary()'",  # maybe do this here? to set our mpi_preferences
        # "julia --project=$(CLIMA)/integration_tests -e 'using MPIPreferences; MPIPreferences.use_system_binary()'",  # maybe do this here? to set our mpi_preferences
        ]
    bash_commands_join = join(bash_commands,"; ")

    julia_precommands = [
        # "using Pkg",
        # "Pkg.develop(path=\"$(Research_Schneider)/CliMa/Thermodynamics.jl\")", # not sure what the right way to replace things is ... do this for the rampy though i could just use pow_icenuc i guess...
        # "Pkg.develop(path=\"$(Research_Schneider)/CliMa/SOCRATESSingleColumnForcings.jl\")", # not sure what the right way to replace things is ... do this for the rampy though i could just use pow_icenuc i guess...
        # "Pkg.instantiate()",
        # "Pkg.precompile()",
        # "Pkg.build()", # not sure if this is necessary
        ]

    julia_precommands_join = join(julia_precommands,"; ")
    # run(`/bin/bash -c "julia --project=$CLIMA/integration_tests/ -e '$julia_precommands_join'"`); exit() # build if necessary, should just have to run this once separately if we need to say update the julia depot or something ...
    if rebuild # I think this --project=<path> needs to match wherever we activate (last?) in single_column_test.jl?
        # idk we need integration_tests to make sure those packages are in, but also need regular if making main TC changes...
        # but if we add new packages in integration_test/ idk how those get updated in toml, I guess we have to run the script?
        println("rebuilding...") # wonder if we're supposed to do this to set the depot and stuff right before buidling... doesn't seem to mater
        #
        # how do we know the top one isn't putting another TC in our julia depot incorreclty i thnk --project=$CLIMA/integration_tests/ is bad here
        #
        run(`/bin/bash -c "$bash_commands_join; julia --project=$CLIMA/integration_tests/ -e 'using Pkg; Pkg.develop(path=\"$CLIMA\"); $julia_precommands_join'"`); # I think we need this to get the packages from integration_tests toml, but it adds a recursive TC to the depot, put a develop to avoid overwriting TC in the depot w/ the online version
        run(`/bin/bash -c "$bash_commands_join; julia --project=$CLIMA/ -e '$julia_precommands_join'"`) # I think we need this to get the packages from regular TC toml
        exit() # don't run anything if we called rebuild
    end
    ## ================================================================================================================ ##

    setup_args = merge(values(setup_args_heirarchy)...) # merged down into just one dictionary...
    sa = setup_args # shorter alias

    ## ================================================================================================================ ##
    # generate list of runs to have by iterating through our heirarchies and applying any filters...

    l_setup_heirarchy = Dict(k=>reduce(*,length.(values(v))) for (k,v) in setup_args_heirarchy ) # dict of lengths of our input arrays
    l_setup = reduce(*,length.(values(sa))) # total linear length
    valid_setups = Array{Union{DataStructures.OrderedDict{String,Any},Missing}}(undef,length.(values(sa))...) # ND array placeholder for our setups (could do a list but this is more clear and could allow for slicing easier later)
    # note: undef might be a bad choice here cause hard to run filters or anything rly wit undef in it, maybe just init as missing...

    # let setup = DataStructures.OrderedDict{Int,Any}()  # let block not necessary inside a fcn right... (do we even use this at all anyway?)

    inds_list_heirarchy = DataStructures.OrderedDict{Int,Any}(k => collect(DataStructures.OrderedDict{String,Any}(keys(v) .=> x)  for x in collect(Base.Iterators.product((eachindex(vv) for vv in values(v))...))) for (k,v) in setup_args_heirarchy) # a dict replacing values with indices in our setup heirarchy dict
    inds_list = collect( DataStructures.OrderedDict{Int,Any}(keys(inds_list_heirarchy) .=> il) for il in Base.Iterators.product(values(inds_list_heirarchy)...) ) # a dict for each k containing pairings of indices taken productwise from those available in inds_lsit_heirarchy
    # @show(inds_list_heirarchy);@show(inds_list)

    for inds in inds_list
        
        full_index = CartesianIndex((CartesianIndex(values(i)...) for i in values(inds))...) # collapse the index lists for each k into one set of cartesian indices for use in our combined ND array
        # println("==============="); println(full_index)

        setup = DataStructures.OrderedDict{Int   ,Any}( k => DataStructures.OrderedDict{String,Any}( kk => setup_args_heirarchy[k][kk][vv] for (kk,vv) in v) for (k,v) in inds) # for each k, replace the inds in our inds dict with the actual values 
        full_setup = DataStructures.OrderedDict{String,Any}( kk => setup_args_heirarchy[k][kk][vv] for (k,v) in inds for (kk,vv) in v ) # collapse the inds in setup into one combined dict
        # @show(full_setup)

        valid=true # could also use Ref(true) and push changes to it b ut using or notation below seems ok...
        #####  filters ------- maybe setup the ability to pass a filter fnc that operates either on a dict like this or on a full_setup full list... idk  #####
        valid_setups_no_undef = valid_setups[filter(i -> isassigned(valid_setups, i) && !ismissing(valid_setups[i]), 1:length(valid_setups))] # fcns dont work on the undef so check that first, then also check not missing

        for custom_filter in custom_filters
            valid &= valid && custom_filter(setup, full_setup, valid_setups_no_undef, setup_args_heirarchy)
            if  !valid 
                break
            end
        end
    

        #####filters -------

        valid_setups[full_index] = valid ? full_setup : missing

    end
    # end

    println("===============================")
    setups_list = vec(valid_setups)
    # display(setups_list)
    display(collect(skipmissing(setups_list)))
    @show(length(collect(skipmissing(setups_list))))


    job_IDs = []
    outdirs = []
    for setup in skipmissing(setups_list) # uses ordered dict so we can guarantee order in keys vals
        setup["adapt_dt"] = setup["dt"] == "adapt" # deal w/ adaptive dt and for file naming stuff
        println(setup)
        suffix = "out" # should I add this to setup or no?
        
        descriptor = rstrip(join([string(key)*"-"*string(val)*"__" for (key,val) in filter( p -> p[1] in keys(setup_args_heirarchy[0]) , setup) ]), '_') # attempt to filter our dict down to this heirarchy level and then automatically generate our names, filter=(if value is in keys we include its value from the pair)jul
        name       = rstrip(join([string(key)*"-"*replace(replace(replace(string(val),(['(',')'].=>"")...),([" = "].=>"-")...),([", ",].=>"__")...)*"__" for (key,val) in filter( p -> p[1] in keys(setup_args_heirarchy[1]) , setup) ]), '_') # strip characters that can't go in name
        name       = replace(string(name),(["user_args-",].=>"")...)

        if isnothing(get(setup, "output_root", nothing)) # could be one ternary operator I guesss, but if missing
            outdir=Research_Schneider*"CliMa/Data/single_column/sensitivity/"*setup["dtime"]*"/" # gotta do something about dtime here... (and allow specified directories)
        else
            outdir = setup["output_root"]
        end
        # @show(setup["output_root"])
        # @show(outdir)

        # sleep(100)

        # outdir = rstrip(outdir,'/')*"_"*Random.randstring('0':'9',8)*"/" # 8 digits should be enough for no conflicts...  deprecate w/ new system

        # doesnt seem to be foolproof...
        # if isdir(outdir)
        # if isdir(outdir*"/"*descriptor*"/"*name*"/") # allow the parent directory to exist as long as the subdir doesn't conflict... that way we can keep consolidated runs together
        #     outdir = rstrip(outdir,'/')*"_1/" # * Random.randstring('0':'9',8) or somethign for true random string ending, stripping and replacing slash if exists
        #     @info("Switching to alternate outdir: "*outdir)
        # end


        outdir = outdir*"/"*descriptor*"/"*name*"/" # the path for this specific parameter arrangement...
        output_root=outdir # default is jus to keep it here i guess, normal default is './' 
        mkpath(outdir) # mkpath I believe creates if doesn't exist...
        log_path=outdir*"/"*"log.out"; #

        slurm_args = deepcopy(default_slurm_args) # placeholder if we wanna make any edits later....
        slurm_args["output"] = log_path

        # I think in julia it's just a list of things so just do that? In bash we passed it in as just a list of strings i guess
        # use this string formatting format so they actually go in as strings not numerics or something
        # CONSIDER SETTING THESE UP TO USE DICT GET OPERATORS TO ALLOW FOR DEFAULT VALUES BETTER (MATCH THE ONES IN SINGLE_COLUMN_TEST.JL?) IDK...
        # args=["--project="*CLIMA*"/", # don't think we need to be in integration_tests still
        #     in_script,
        #     "--case "*setup["case"],
        #     "--output_root "*output_root,
        #     "--skip_tests="*string(setup["skip_tests"]),
        #     "--moisture_model " * setup["moisture_model"],
        #     "--precipitation_model " * setup["precipitation_model"],
        #     "--sgs " * setup["sgs"],
        #     # "--tau_sub_dep "*string(setup["tau_sub_dep"]),
        #     # "--tau_cond_evap "*string(setup["tau_cond_evap"]),
        #     # "--tau_frz_mlt "*string(["tau_frz_mlt"]),
        #     "--adapt_dt " *string(setup["adapt_dt"]),
        #     "--dt " *string(setup["dt"]),
        #     "--t_max " *string(setup["t_max"]),
        #     "--suffix "*suffix,
        #     # "--user_args "*get(setup, "user_args", "(;))()"), # use default otherwise... # took from sampo, but below seems to work so i assume this is wrong? maybe it worked too i cant recall , sampo aint got slurm anyway
        #     "--user_args " * "\\\"" * string(get(setup, "user_args", (;))) * "\\\""  # use default otherwise..., double quotes on command line, outer to make a string not bash variable input (to preserve julia syntax), and inner so julia sees it as a eval string to send to Meta.parse
        #     ]

        args = ["--project="*CLIMA*"/", # don't think we need to be in integration_tests still
            in_script,
            "--output_root "*output_root,
            "--suffix "*suffix,
            "--user_args " * "\\\"" * string(get(setup, "user_args", (;))) * "\\\"",  # use default otherwise..., double quotes on command line, outer to make a string not bash variable input (to preserve julia syntax), and inner so julia sees it as a eval string to send to Meta.parse
            "--user_aux "  * "\\\"" * string(get(setup, "user_aux" , (;))) * "\\\""
            ]  # use default otherwise..., double quotes on command line, outer to make a string not bash variable input (to preserve julia syntax), and inner so julia sees it as a eval string to send to Meta.parse
        
        for key in keys(setup) # add remaining keys from setup to args list, skiping those we already took care of.
            if key ∉ ["user_args","user_aux","dtime","output_root","suffix"]
                push!(args,"--"*key*" "*string(setup[key]))
            end
        end

        sysimage = sysimage==true ? CLIMA*"/"*"TurbulenceConvection_image.so" : sysimage

        @show(sysimage)
        if !(sysimage == false)
            @info("Using system image at "*sysimage)
            pushfirst!(args, "--sysimage "*sysimage) # push to front so is not an argument of in_script
            @show(args)
        end


        julia_command_options = join(args," ")

        # run(`julia --project=$CLIMA) -e 'using MPIPreferences; MPIPreferences.use_system_binary()'`) # test setting MPI preferences this way for new MPIPreferences package

        full_command = "--wrap=\""*bash_commands_join*"; mpirun julia --color yes $julia_command_options\"" # this the jawn we needed on god https://stackoverflow.com/a/33402070, wrap means sbatch wraps the string inside a sh call which helps with interpreting esp special characters and strings..., # backticks means a call to shell too
        println(full_command); println("")
        processed_slurm_args = ["--"*k*"="*string(v) for (k,v) in slurm_args] #get into a nice list of strings like slurm requires...

        job_ID = SlurmTools.sbatch(full_command, processed_slurm_args) # seems to work... # there's no slurm on julia so we just gotta run it no?
        job_ID = parse(Int,split(job_ID)[end]) # get to Int
        push!(job_IDs, job_ID)
        push!(outdirs, outdir)


        # fix this up so we don't even need to use that whole slurmtools jawn, it just runs w/ parsable n shit, i guess chomp would do it anyway? idk.... maybe this still easier...
        # or edit the local version to do the wrapping by itself.... maybe would print more out w/o parseable, which seems to return less... returns only job id....

        println("========================================================================================================")

    end

return job_IDs, outdirs
end