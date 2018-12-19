include("migration.jl")

module Decision
    using StatsBase
    using Match
    using ..Migration

    function choose_initial_vaccinators(society)
        island_population = div(society.total_population, society.num_island)
        initial_v = []
        for i = 1:num_island
            island_i = Vector(1+(i+1)island_population:i*island_population)
            push!(initial_v, StatsBase.self_avoid_sample!(island_i, Vector(1:div(island_population, 2))))
        end

        return initial_v
    end

    function initialize_strategy(society, initial_v)
        for i = 1:society.total_population
            society.strategy[i] = ifelse(i in initial_v, "V", "NV")
        end

        return society
    end

    function count_payoff(society, cr)
        state = society.state
        strategy = society.strategy
        point = society.point

        for i = 1:society.total_population
            gain = @match [state[i], strategy[i]] begin
                ["S", "V"]  => -cr
                ["S", "NV"] => 0
                ["IM", "V"] => -cr
                ["R", "V"]  => -cr-1
                ["R", "NV"] => -1
                _  => println("Error in count_payoff")
            end
            point[i] += gain
        end

        return society
    end

    function pairwise_fermi(society)
        strategy = society.strategy
        point = society.point

        islands = Migration.get_islands(society)
        next_strategy = []
        for i = 1:society.total_population
            my_island = society.island_id[i]
            opp_candidates = filter(opp_id -> opp_id != i, islands[my_island])
            opp_id = rand(opp_candidates)
            if strategy[opp_id] =! strategy[i] && rand() < = 1/( 1 + exp( (point[i] - point[opp_id])/0.1 ) )
                push!(next_strategy, strategy[opp_id])
            else
                push!(next_strategy, strategy[id])
            end
        end
        society.strategy = next_strategy

        return society
    end
end