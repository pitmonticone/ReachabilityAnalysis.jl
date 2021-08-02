using .DifferentialEquations
const DE = DifferentialEquations

# extend the solve API for initial-value problems
function _solve_ensemble(ivp::InitialValueProblem, args...;
                         trajectories=100,
                         trajectories_alg=DE.Tsit5(),
                         ensemble_alg=DE.EnsembleThreads(),
                         inplace=true,
                         initial_states=nothing,
                         kwargs...)

    # get problem's vector field
    if inplace
        field = inplace_field!(ivp)
    else
        field = outofplace_field(ivp)
    end

    # get time span
    dt = _get_tspan(args...; kwargs...)
    tspan = (inf(dt), sup(dt))

    if isnothing(initial_states)
        # sample initial states of the IVP
        X0 = initial_state(ivp)
        sampler = get(kwargs, :sampler, LazySets._default_sampler(X0))
        rng = get(kwargs, :rng, LazySets.GLOBAL_RNG)
        seed = get(kwargs, :seed, nothing)
        include_vertices = get(kwargs, :include_vertices, false)
        initial_states = sample(X0, trajectories; sampler=sampler, rng=rng,
                                seed=seed, include_vertices=include_vertices)
    else
        trajectories = length(initial_states)
    end

    # formulate ensemble ODE problem
    ensemble_prob = ODEProblem(field, first(initial_states), tspan)
    _prob_func(prob, i, repeat) = remake(prob, u0 = initial_states[i])

    # choose tolerances
    reltol = get(kwargs, :reltol, 1e-3)
    abstol = get(kwargs, :abstol, 1e-6)

    ensemble_prob = EnsembleProblem(ensemble_prob, prob_func = _prob_func)
    return DE.solve(ensemble_prob, trajectories_alg, ensemble_alg;
                    trajectories=trajectories, reltol=reltol, abstol=abstol)
end
