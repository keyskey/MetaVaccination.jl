include("migration.jl")
include("society.jl")

module Epidemics
    using StatsBase
    using Match
    using ..Society
    using ..Migration

    function initialize_state(society::SocietyType; beta::Float64=0.83, gamma::Float64=1/3, m_rate::Float64=0.2, effectiveness::Float64=1.0, num_i_each_island::Int=1)
        reset_counters(society)
        initial_infection(society, effectiveness, num_i_each_island)
        set_initial_total_transition_probability(society, beta, gamma, m_rate)
    end

    # Initialize num_s/i/r, survivors, accum_day
    function reset_counters(society::SocietyType)
        n = society.num_island
        island_size       = div(society.total_population, n) 
        society.num_s     = fill(0, n)   # Need to count
        society.num_im    = fill(0, n)   # Need to count
        society.num_i     = fill(0, n)   # Need to count
        society.num_e     = fill(0, n)   # Determined
        society.num_r     = fill(0, n)   # Determined
        society.elapse_days = 0          # Determined
        society.survivors = []           # Need to push
    end

    function initial_infection(society::SocietyType, effectiveness::Float64, num_i_each_island::Int)
        non_v_island = fill([], society.num_island)   # Initially infected people are chosen from non vaccinators
        for i = 1:society.total_population
            my_island = society.island_id[i]

            # Vaccinators can get perfect immunity or keep susceptible
            if society.strategy[i] == "V"
                if rand() <= effectiveness
                    society.state[i] = "IM"
                    society.num_im[my_island] += 1
                else
                    society.state[i] = "S"
                    society.num_s[my_island] += 1
                    push!(society.survivors,i)
                end

            # Non-vaccinators are always susceptible at initial day of the season
            elseif society.strategy[i] == "NV"
                society.state[i] = "S"
                society.num_s[my_island] += 1
                push!(society.survivors, i)
                push!(non_v_island[my_island], i)
            end
        end
        
        # Select initially infected people from non-vaccinators in each island
        for i in collect(Iterators.Flatten([StatsBase.self_avoid_sample!(non_v_island[island], collect(1:num_i_each_island)) for island = 1:society.num_island]))
            my_island = society.island_id[i]
            society.state[i] = "I"
            society.num_s[my_island] -= 1
            society.num_i[my_island] += 1
        end
    end
    
    # Count total transition probability. Only used inside initialize_state function.
    function set_initial_total_transition_probability(society::SocietyType, beta::Float64, gamma::Float64, m_rate::Float64)
        society.total_transition_probability = 0
        for island = 1:society.num_island
            Ps_e  = beta * society.num_i[island]
            Pi_r = gamma
            society.total_transition_probability += (Ps_e + m_rate) * society.num_s[island] + Pi_r * society.num_i[island]  
        end
    end

    # Count total transition probability. Used during SIR days in every seasons.
    function set_total_transition_probability(society::SocietyType, beta::Float64, alpha::Float64, gamma::Float64, m_rate::Float64)
        society.total_transition_probability = 0
        for island = 1:society.num_island
            Ps_e = beta * society.num_i[island]
            Pe_i = alpha
            Pi_r = gamma
            society.total_transition_probability += (Ps_e + m_rate) * society.num_s[island] + (Pe_i + m_rate) * society.num_e[island] + Pi_r * society.num_i[island]  
        end
    end

    function desease_spreading(society::SocietyType, id::Int)
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

    function state_change(society::SocietyType; beta::Float64=0.83, gamma::Float64=1/3, alpha::Float64=1/7, m_rate::Float64=0.2)
        rand_num::Float64 = rand()
        accum_probability::Float64 = 0
        no_one_changed::Bool = true
        migrated::Bool = false

        # Go to desease_spreading
        for i in society.survivors
            my_island = society.island_id[i]
            accum_probability += @match society.state[i] begin
                "S" => beta * society.num_i[my_island]/society.total_transition_probability
                "E" => alpha/society.total_transition_probability
                "I" => gamma/society.total_transition_probability
                 _  => error("Error in state change, my state doesn't match with S/E/I")
            end

            if rand_num <= accum_probability
                desease_spreading(society, i)
                no_one_changed = false 
                migrated = false
                break  # Escape from survivors loop
            end
        end

        # If go to migration
        if no_one_changed
            for i in society.survivors
                accum_probability += ifelse(society.state[i] in ["S", "E"], m_rate/society.total_transition_probability, 0)
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
        elapse_days = count_elapse_days(society)

        return migrated, elapse_days
    end

    function count_elapse_days(society::SocietyType)
        society.elapse_days += log(1/rand())/society.total_transition_probability
        return society.elapse_days
    end
end
