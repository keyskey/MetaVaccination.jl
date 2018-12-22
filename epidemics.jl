include("migration.jl")

module Epidemics
    using StatsBase
    using Match
    using ..Migration


    function initialize_state(society, beta, gamma, effectiveness, m_rate, num_i_each_island)
        reset_parameters(society, num_i_each_island)
        initialze_vaccinators(society, effectiveness)
        initialize_non_vaccinators(society, num_i_each_island)
        set_total_transition_probability(society, beta, gamma, m_rate)
    end

    # Initialize num_s/i/r, survivors, accum_day
    function reset_parameters(society, num_i_each_island)
        n = society.num_island
        island_size       = div(society.total_population, n) 
        society.num_s     = fill(island_size - num_i_each_island, n)  # Determined
        society.num_im    = fill(0, n)                                # Need to count
        society.num_i     = fill(num_i_each_island, n)                # Determined
        society.num_r     = fill(0, n)                                # Determined
        society.survivors = []
        society.accum_day = 0
    end

    # Determine the initial state of vaccinators(= IM or S)  
    function initialze_vaccinators(society, effectiveness)
        vaccinators = [id for (id, strategy) in enumerate(society.strategy) if strategy == "V"]
        for i in vaccinators
            my_island = society.island_id[i]
            if rand() <= effectiveness  # Successful vaccinators
                society.state[i] = "IM"
                society.num_im[my_island] += 1
            else                        # Failed vaccinators
                society.state[i] = "S" 
                push!(society.survivors, i)
            end
        end
    end

    function initialize_non_vaccinators(society, num_i_each_island)
        non_vaccinators = [id for (id, strategy) in enumerate(society.strategy) if strategy == "NV"]
        non_v_island = fill([], society.num_island) # Initially infected people are chosen from non vaccinators
        for i in non_vaccinators
            my_island = society.island_id[i]
            society.state[i] = "S"
            push!(society.survivors, i)
            push!(non_v_island[my_island], i)
        end

        # Set initially infected people from each island
        for i in collect(Iterators.Flatten([ StatsBase.self_avoid_sample!(non_v_island[island], collect(1:num_i_each_island)) for island = 1:society.num_island ]))
            society.state[i] = "I"
        end
    end

    function set_total_transition_probability(society, beta, gamma, m_rate)
        society.total_transition_probability = 0
        for island = 1:society.num_island
            Ps_i  = beta * society.num_i[island]
            Pi_r = gamma
            society.total_transition_probability += Ps_i * society.num_s[island] + (Pi_r + m_rate) * society.num_i[island]  
        end
    end
    

    function desease_spreading(society, id)
        my_island = society.island_id[id]
        @match society.state[id] begin
            "S" =>
              begin
                society.state[id] = "I"
                society.num_s[my_island] -= 1
                society.num_i[my_island] += 1
              end
            "I" =>
              begin
                society.state[id] = "R"
                society.num_i[my_island] -= 1
                society.num_r[my_island] += 1
                filter!(survivor_id -> survivor_id != id, society.survivors)  # Remove this agent from survivors
              end
            _ => error("Error in desease spreading, R or the other state is picked up in gillespie method")
        end
    end

    function state_change(society, beta, gamma, m_rate)
        rand_num = rand()
        accum_probability = 0
        no_one_changed = true

        # If go to desease_spreading
        for i in society.survivors
            my_island = society.island_id[i]
            accum_probability += @match society.state[i] begin
                "S" => beta * society.num_i[my_island]/society.total_transition_probability
                "I" => gamma/society.total_transition_probability
                 _  => error("Error in state change, my state doesn't match with S/I")
            end

            if rand_num <= accum_probability
                desease_spreading(society, i)
                no_one_changed = false  # <- Don't allow migration after this loop !!
                global migrated = false
                break  # Escape from survivors loop
            end
        end

        # If go to migration
        if no_one_changed
            for i in society.survivors
                accum_probability += ifelse(society.state[i] == "I", m_rate/society.total_transition_probability, 0)
                if rand_num <= accum_probability
                    Migration.random_migration(society, i)
                    no_one_changed = false
                    global migrated = true
                    break  # -> Escape from survivors loop
                end
            end
        end

        if no_one_changed
            error("Error in state change, none of desease spreading or migration happened")
        end

        set_total_transition_probability(society, beta, gamma, m_rate)

        return migrated
    end
end
