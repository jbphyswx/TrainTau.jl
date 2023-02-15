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
    """

    return [b,c,d]' * [T = TD.air_temperature(ts), q_tot.liq, q_tot.ice]

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
