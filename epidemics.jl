include("migration.jl")

module Epidemics
    using StatsBase
    using Match
    using ..Migration

    function initialize_state(society, beta, gamma, effectiveness, m_rate, num_i_each_island)
        reset_parameters(society)
        set_initial_state(society, effectiveness, num_i_each_island)
        set_total_transition_probability(society, beta, gamma, m_rate)
    end

    # Initialize num_s/i/r, survivors, accum_day
    function reset_parameters(society)
        n = society.num_island
        island_size       = div(society.total_population, n) 
        society.num_s     = fill(0, n)   # Need to count
        society.num_im    = fill(0, n)   # Need to count
        society.num_e     = fill(0, n)   # Determined
        society.num_i     = fill(0, n)   # Determined
        society.num_r     = fill(0, n)   # Determined
        society.survivors = []
        society.accum_day = 0
    end

    function set_initial_state(society, effectiveness, num_i_each_island)
        non_v_island = fill([], society.num_island)   # Initially infected people are chosen from non vaccinators
        for i = 1:society.total_population
            my_island = society.island_id[i]
            if society.strategy[i] == "V"
                if rand() <= effectiveness
                    society.state[i] = "IM"
                    society.num_im[my_island] += 1
                else
                    society.state[i] = "S"
                    society.num_s[my_island] += 1
                    push!(society.survivors,i)
                end
            elseif society.strategy[i] == "NV"
                society.state[i] = "S"
                society.num_s[my_island] += 1
                push!(society.survivors, i)
                push!(non_v_island[my_island], i)
            end
        end
        
        for i in collect(Iterators.Flatten([StatsBase.self_avoid_sample!(non_v_island[island], collect(1:num_i_each_island)) for island = 1:society.num_island]))
            my_island = society.island_id[i]
            society.state[i] = "I"
            society.num_s[my_island] -= 1
            society.num_i[my_island] += 1
        end
    end

    function set_total_transition_probability(society, beta, alpha, gamma, m_rate)
        society.total_transition_probability = 0
        for island = 1:society.num_island
            Ps_e = beta * society.num_i[island]
            Pe_i = alpha
            Pi_r = gamma
            society.total_transition_probability += (Ps_e + m_rate) * society.num_s[island] + (alpha + m_rate) * society.num_e[island] + Pi_r * society.num_i[island]  
        end
    end

    function set_total_transition_probability(society, beta, gamma, m_rate)
        society.total_transition_probability = 0
        for island = 1:society.num_island
            Ps_e  = beta * society.num_i[island]
            Pi_r = gamma
            society.total_transition_probability += (Ps_e + m_rate) * society.num_s[island] + Pi_r * society.num_i[island]  
        end
    end

    function desease_spreading(society, id)
        my_island = society.island_id[id]
        @match society.state[id] begin
            "S" =>
              begin
                next_state = "E"
                society.num_s[my_island] -= 1
                society.num_e[my_island] += 1
              end
            "E" =>
              begin
                next_state = "I"
                society.num_e[my_island] -= 1
                society.num_i[my_island] += 1
              end
            "I" =>
              begin
                next_state = "R"
                society.num_i[my_island] -= 1
                society.num_r[my_island] += 1
                filter!(survivor_id -> survivor_id != id, society.survivors)
              end
            _ => error("Error in desease spreading, R or the other state is picked up in gillespie method")
        end
        society.state[id] = next_state
    end

    function state_change(society, beta, gamma, alpha, m_rate)
        rand_num = rand()
        accum_probability = 0
        no_one_changed = true
        migrated = false

        # Go to desease_spreading
        for i in society.survivors
            my_island = society.island_id[i]
            accum_probability += @match society.state[i] begin
                "S" => beta * society.num_i[my_island]/society.total_transition_probability
                "E" => alpha/society.total_transition_probability
                "I" => gamma/society.total_transition_probability
                 _  => error("Error in state change, my state doesn't match with S/I")
            end

            if rand_num <= accum_probability
                desease_spreading(society, i)
                no_one_changed = false 
                migrated = false
                if society.num_i[my_island] < 0
                    println("Error happened due to agent $i after desease_spreading, whose state is ", society.state[i])
                    error("Num I = $(society.num_i[my_island]) at $i")
                end
                break  # Escape from survivors loop
            end
        end

        # If go to migration
        if no_one_changed
            for i in society.survivors
                accum_probability += ifelse(society.state[i] in ["S", "E"], m_rate/society.total_transition_probability, 0)
                #accum_probability += ifelse(society.state[i] == "I", m_rate/society.total_transition_probability, 0)
                if rand_num <= accum_probability
                    Migration.SE_random_migration(society, i)
                    #Migration.random_migration(society, i)
                    no_one_changed = false
                    migrated = true
                    break  # Escape from survivors loop
                end
            end
        end

        if no_one_changed
            error("Error in state change, none of desease spreading or migration happened")
        end

        set_total_transition_probability(society, beta, alpha, gamma, m_rate)

        return migrated
    end
end
