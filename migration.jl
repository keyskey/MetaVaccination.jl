module Migration

    # Return the nested list of agent ID grouped by each island
    function get_islands(society)
        islands = fill([], society.num_island)
        for i = 1:society.total_population
            my_island = society.island_id[i]
            push!(islands[my_island], i)
        end

        return islands
    end

    # Reallocate all agents to their original island
    function reset_island(society)
        island_population = div(society.total_population, society.num_island)
        society.island_id = collect(Iterators.Flatten([fill(i, island_population) for i = 1:society.num_island ]))
    end

    # Randomely migrate the given agent
    function random_migration(society, migrator_id)
        my_island = society.island_id[migrator_id]
        next_island = rand(society.linked_island[my_island])  # Decide destination
        society.num_i[my_island] -= 1
        society.island_id[migrator_id] = next_island          # Migrate  
        society.num_i[next_island] += 1
    end

    # Randomely migrate S or E agent
    function SE_random_migration(society, migrator_id)
        my_island = society.island_id[migrator_id]
        next_island = rand(society.linked_island[my_island])
        if society.state[migrator_id] == "S"
            society.num_s[my_island] -=1
            society.num_s[next_island] += 1
        elseif society.state[migrator_id] == "E"
            society.num_e[my_island] -= 1
            society.num_e[next_island] += 1
        end
        society.island_id[migrator_id] = next_island
    end
end
