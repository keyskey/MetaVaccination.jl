module Society
    using Statistics
    export SocietyType

    mutable struct  SocietyType
        num_island::Int
        total_population::Int

        # Length: num_island
        island_population::Vector{Int}
        linked_island::Vector{Vector{Int}}
        num_s::Vector{Int}   # Failed vaccinators + Non vaccinators
        num_im::Vector{Int}  # = Immuned state (= Successful vaccinators)
        num_e::Vector{Int}
        num_i::Vector{Int}
        num_r::Vector{Int}

        # Length: total_population
        state::Vector{AbstractString}  # S, IM, E, I, R
        strategy::Vector{AbstractString} # V or NV
        point::Vector{Float64}
        survivors::Vector{Int}
        island_id::Vector{Int}
        
        total_transition_probability::Float64
        accum_day::Float64
        
        # Constructor
        SocietyType(total_population, num_island, topology) = new(
            num_island,                                                                      # num_island
            total_population,                                                                # total_population
            fill(div(total_population, num_island), num_island),                             # island_population
            [ [ island_id+1 for island_id in topology[i] ] for i = 1:num_island ],           # linked_island
            zeros(num_island),                                                               # num_s
            zeros(num_island),                                                               # num_im
            zeros(num_island),                                                               # num_e
            zeros(num_island),                                                               # num_i 
            zeros(num_island),                                                               # num_r
            fill(" ", total_population),                                                     # state
            fill(" ", total_population),                                                     # strategy
            zeros(total_population),                                                         # point
            [],                                                                              # survivors
            collect(Iterators.Flatten([fill(i, div(total_population, num_island)) for i = 1:num_island])),  # island_id
            0,                                                                               # total_transition_probability
            0                                                                                # accun_day
            )  
    end

    function count_state_fraction(society)
        n_tot = society.total_population
        fs = sum(society.num_s)/n_tot
        fim = sum(society.num_im)/n_tot
        fe = sum(society.num_e)/n_tot
        fi = sum(society.num_i)/n_tot
        fr = sum(society.num_r)/n_tot
        
        return fs, fim, fe, fi, fr
    end

    count_fv(society) = length(filter(strategy -> strategy == "V", society.strategy))/society.total_population

    count_SAP(society) = Statistics.mean(society.point)
end
