function post_process_folder(out_folder, tau, verbose=false, save=true)
    """ if we ran the model but didnt' save weights n stuff we should be able to recalculate them 
    - allow for self discovery later, for now let's say you have to give the weights you used
    """

    if save
        output_save_path     = out_folder*"/grid_search_log.out"
        output_save_path_pkl = out_folder*"/"*"grid_search_log.out.pkl"
    end

    sz_tau = (x->size(x)[1]).(values(tau)) 


    loss_array = fill(NaN,sz_tau)
    dir_array  = fill("",sz_tau)

    for (i,tau_liq)=enumerate(tau.liq), (j,tau_ice)=enumerate(tau.ice)
        tau_params = (;log10_tau_liq=tau_liq,log10_tau_ice=tau_ice) # for easy string interpolation below...
        output_root = out_folder *"/"*  rstrip(join([string(key)*"-"*string(val)*"__" for (key,val) in zip(keys(tau_params), tau_params)]),'_') *"/" # problematic for this represenation with parentheses in expr


        output_files = []
        try
            dirs = readdir(output_root, join=true)
                    # @show(dirs)
            for dir = dirs
                # @show( dir * "/*/*/*/*.nc")
                try
                    file = Glob.glob( "*/*/*/*.nc",dir)[1]
                    # @show(file)
                    push!(output_files,file)
                catch 
                    if verbose; @show("failed for:  "* dir); end
                end
            end 

            # @show(length(output_files))
            model_outputs = Dict()
            for output in output_files
                loc = findfirst("RF",output)
                flight_number = parse(Int,output[loc[end]+1:loc[end]+2])
                model_outputs[flight_number] =  NCDatasets.Dataset(output,"r")
            end
            # @show(model_outputs)
            loss = TrainTau.SOCRATES_loss(model_outputs)

            loss_array[i,j] = loss
            dir_array[ i,j] = output_root



            
        catch
            if verbose; @show("failed for: ", output_root); end
            continue # skip rest of loop
        end

    end

    # save 
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
end