include("society.jl")
include("epidemics.jl")
include("decision.jl")

module Simulation
    using ..Society
    using ..Epidemics
    using ..Decision
    using ..Migration
    using Random
    using CSV
    using DataFrames
    using Statistics
    using Printf

    # Calculation for a pair of Cr and Effectiveness. Continue until fv reaches to equilibrium
    function season_loop(society, beta, alpha, gamma, m_rate, cr, e, init_v, num_i_each_island)
        Decision.initialize_strategy(society, init_v)
        fv_hist = []

        fv0 = Society.count_fv(society)
        @printf("Cr: %.1f e: %.1f Initial Season => Fv: %.3f \n", cr, e, fv0)

        # Strategy update loop
        for season = 1:3000
            Epidemics.initialize_state(society, beta, gamma, e, m_rate, num_i_each_island)
            fs0, fim0, fe0, fi0, fr0 = Society.count_state_fraction(society)
            @printf("Cr: %.1f e: %.1f Season: %i Step: 0 Fs: %.4f Fim: %.4f Fe: %.4f Fi: %.4f Fr: %.4f \n", cr, e, season, fs0, fim0, fe0, fi0, fr0)

            # SIR dynamics loop
            for step = 1:1000000
                migrated = Epidemics.state_change(society, beta, alpha, gamma, m_rate)
                global fs, fim, fe, fi, fr = Society.count_state_fraction(society)
                @printf("Cr: %.1f e: %.1f Season: %i Step: %i Fs: %.4f Fim: %.4f Fe: %.4f Fi: %.4f Fr: %.4f Migrated: %s \n", cr, e, season, step, fs, fim, fe, fi, fr, migrated)

                # Check conversion
                if fe == 0 && fi == 0
                    break
                end
            end

            # Update strategy after coming back to the original island
            Migration.reset_island(society)
            Decision.count_payoff(society, cr)
            Decision.pairwise_fermi(society)
            global fv = Society.count_fv(society)
            push!(fv_hist, fv)
            @printf("Cr: %.1f e: %.1f Season: %i Fv: %.3f \n", cr, e, season, fv)

            # Check whether fv reaches to equilibrium or not
            if fv == 0 || fv == 1
                break
            elseif season >= 100 && (Statistics.mean(fv_hist[season-99:season])-fv)/fv <= 0.001
                break
            end
        end

        FES = fr
        VC = fv
        SAP = Society.count_SAP(society)

        return FES, VC, SAP
    end

    # Get data for one Cr-Effectiveness phase diagram
    function one_episode(society, episode)
        Random.seed!()
        DataFrame(Cr = [], Effectiveness = [], FES = [], VC = [], SAP = []) |> CSV.write("result$episode.csv")  # Write header
        gamma = 1/3
        m_rate = 0.01
        num_i_each_island = 1

        init_v = Decision.choose_initial_vaccinators(society)
        for beta in [0.00037]
            for alpha in [1/7]
                for cr in [0.7] # = 0:0.1:1
                    for e in [0.8, 0.9] # = 0:0.1:1
                        FES, VC, SAP = season_loop(society, beta, alpha, gamma, m_rate, cr, e, init_v, num_i_each_island)
                        DataFrame(Cr = [cr], Effectiveness = [e], FES = [FES], VC = [VC], SAP = [SAP]) |> CSV.write("result$episode.csv", append=true)
                    end
                end
            end
        end
    end

    # Main function
    function run(num_episode, total_population, num_island, topology)
        society = Society.SocietyType(total_population, num_island, topology)
        for episode = 1:num_episode
            one_episode(society, episode)
        end
    end
end

using .Simulation
using PyCall
@pyimport networkx as nx

const num_episode = 1
const total_population = 14000
const num_island = 7
const topology = nx.star_graph(num_island-1)
#const topology = nx.circulant_graph(num_island, [1])
#const topology = nx.wheel_graph(num_island)
#const topology = nx.complete_graph(num_island)

Simulation.run(num_episode, total_population, num_island, topology)
