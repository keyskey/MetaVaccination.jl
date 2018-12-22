include("migration.jl")

module Decision
    using StatsBase
    using Match
    using ..Migration

    function choose_initial_vaccinators(society)
        island_population = div(society.total_population, society.num_island)
        initial_v = []
        for i = 1:society.num_island
            island_i = Vector(1+(i-1)*island_population:i*island_population)
            push!(initial_v, StatsBase.self_avoid_sample!(island_i, Vector(1:div(island_population, 2))))
        end
        initial_v = collect(Iterators.Flatten(initial_v))

        return initial_v
    end

    function initialize_strategy(society, initial_v)
        for i = 1:society.total_population
            society.strategy[i] = ifelse(i in initial_v, "V", "NV")
        end
        
    end

    function count_payoff(society, cr)
        state = society.state
        strategy = society.strategy

        for i = 1:society.total_population
            society.point[i] += @match state[i], strategy[i] begin
                "S", "V"   => -cr
                "S", "NV"  => 0
                "IM", "V"  => -cr
                "IM", "NV" => error("Error in count_payoff, IM & NV pair detected")
                "R", "V"   => -cr-1
                "R", "NV"  => -1
                "I", "V"   => error("Error in count_payoff, I & V pair detected")
                "I", "NV"  => error("Error in count_payoff, I & NV pair detected")
                 _ , _      => error("Error in count_payoff")
            end
        end
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
            if strategy[opp_id] != strategy[i] && rand() <= 1/( 1 + exp( (point[i] - point[opp_id])/0.1 ) )
                push!(next_strategy, strategy[opp_id])
            else
                push!(next_strategy, strategy[i])
            end
        end
        strategy = next_strategy
    end
end