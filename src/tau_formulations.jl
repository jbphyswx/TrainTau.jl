"""
This holds different formluations of the tau parameters
"""

FT = Float64

function tau1(b::FT,c::FT,d::FT, ts, q_tot)
    """
    a * (qv_sat_liq - qv_sat_ice) (just a function of T so removed for now) -- can add back later or maybe it will get learned itself.
    b * (q_liq)
    c * (q_ice)
    d * T

    # b,c,d are vectors with two values one for liq one for ice...
    """

    arr = vcat(a',b',c')



    return arr' * [T = TD.air_temperature(ts), q_tot.liq, q_tot.ice]

end


function tau1(b::FT,c::FT,d::FT, locals)
    """
    a * (qv_sat_liq - qv_sat_ice) (just a function of T so removed for now) -- can add back later or maybe it will get learned itself.
    b * (q_liq)
    c * (q_ice)
    d * T
    """
    ts    = locals[:ts]
    q_tot = locals[:q_tot]
    return tau1(b,c,d, ts, q_tot)

end



function tau2(locals; tau_liq=10, tau_ice,10 )
    """
    """
    return [tau_liq, tau_ice]
end

function tau2(w;locals)
    return w[1], w[2] 
end


function tau3(w,locals) # train in log space... (probably more stable...)
    return 10^w[1], 10^w[2] 
end



function tau_log(w;locals)
    return w[1], w[2] 
end
