```@meta
DocTestSetup = :(using ReachabilityAnalysis)
CurrentModule = ReachabilityAnalysis
```

# Nonlinear ordinary differential equations

## Overview

Reachability analysis applies to nonlinear systems, i.e. those where the right-hand
side of the ODE is a nonlinear function of the state variables. Such systems
play a central role in applied mathematics. In this section we explain how to solve
nonlinear reachability problems using `ReachabilityAnalysis.jl` and comment on some
noteworthy differences between the user interface of nonlinear vs. linear systems.
Since nonlinear reachability methods suffer from wrapping effects, we explain some
common techniques to improve error bounds, such as splitting and refinement.
Computing accurately and efficiently the sets of states reachable by nonlinear ODEs
is a hard mathematical and computational problem. The methods available in this
library are just a small portion of the active and rapidly evolving research
literature.

In the rest of this section we take, as our running example, the well-known
[Lotka-Volterra equations](https://en.wikipedia.org/wiki/Lotka%E2%80%93Volterra_equations).
The two-dimensional Lotka-Volterra system depicts the populations change of a class of predators and a class of preys. The growth rate of preys' population $x$ over time is given by

```math
\dot{x} = x\cdot (\alpha - \beta \cdot y)
```
wherein  $\alpha, \beta$ are constant parameters and $y$ is the population of predators.
This equation states that the number of preys grows exponentially without predation.
On the other hand, the population growth of predators is governed by the differential
equation

```math
\dot{y} = -y\cdot (\gamma - \delta\cdot x)
```
wherein  $\gamma, \delta$ are constant parameters.

A typical choice of parameter values is $\alpha = 1.5$, $\beta = 1$,
$\gamma = 3$ and $\delta = 1$. In the next section we consider these values, and
compute the set of states reachable varying the initial condition. After, we assume
that the paramters are only known within given intervals, and compute the flowpipe
for all possible values of the parameters and initial conditions.

## Problem formulation

nonlinear systems can be computed by stating and solving an initial-value
problem for the given , similarly to the case of linear systems, but using different algorithms

The first set
We introduce the vector $\

```@example lotka_volterra
using ReachabilityAnalysis

@taylorize function lotka_volterra!(du, u, p, t)
    local α, β, γ, δ = 1.5, 1.0, 3.0, 1.0
    x, y = u
    du[1] = x * (α - β*y)
    du[2] = -y * (γ - δ*x)
end
```

## Computing with Taylor models

The reachability settings are taken from [this resource](https://ths.rwth-aachen.de/research/projects/hypro/lotka-volterra/).

We consider the initial set  $x\in [4.8,5.2], y \in [1.8,2.2]$.

```@example lotka_volterra
X₀ = Hyperrectangle(low=[4.8, 1.8], high=[5.2, 2.2])

prob = @ivp(x' = lotka_volterra!(x), dim: 2, x(0) ∈ X₀)
```

## Results

We compute the flowpipe using the TMJets algorithm for the time horizon $[0,5]$:

```@example lotka_volterra
sol = solve(prob, T=5.0)

setrep(sol)
```

We can change to the zonotopic overapproximation of the flowpipe using
the `overapproximate` function:

```@example lotka_volterra
sol = overapproximate(sol, Zonotope)

setrep(sol)
```

Finally we plot the solution in phase-space:

```@example lotka_volterra
using Plots

plot(sol, vars=(1, 2), xlab="x", ylab="y", lw=0.2, color=:lightblue, lab="Flowpipe")
plot!(X₀, color=:orange, lab="Xo")
```

## Domain splitting

A common technique to reduce wrapping effects is to split the set of initial
states. If an initial-value problem has been setup with an *array of sets*, then
the flowpipe starting from each initial set scomputed in parallel, using Julia's
built-in multithreaded support.

```julia

```

!!! note
    To turn off multithreading, pass the `multithreaded=false` option flag to
    `solve` method. It is `true` by default.


!!! note
    To change the number of threads being used, change the `THREADS` flag in . . .


## Some common gotchas

We end this section with some technical aspects regarding the formulation of
initial-value problems for nonlinear systems.

### What is `@taylorize`? Do I need it?

`@taylorize` is a macro which parses the functions containing the ODEs to be integrated,
allowing to speed up repeated evaluations. The macro is defined in
[TaylorIntegration.jl](https://github.com/PerezHz/TaylorIntegration.jl), see
[`@taylorize`'s documentation in TaylorIntegration.jl](https://perezhz.github.io/TaylorIntegration.jl/stable/taylorize/)
for further details. Since it is an optimization, it is *not* mandatory,
though it is recommended as it helps to reduce the number of allocations and as a
consequence it usually gives a performance boost.

### How can I get the most out of `@taylorize`?

The main advice is to refactor expressions involving several terms into smaller
expressions which involve at most two arguments, making appropriate use of parentheses
if needed. For further limitations and advice see [this section of TaylorInegrations.jl's
documentation](https://perezhz.github.io/TaylorIntegration.jl/stable/taylorize/#Limitations-and-some-advices-1).

**Example.** Here is an example that uses some of the above recommendations.
Start with `f!` defined below:

```julia
@taylorize function f!(du, u, params, t)
    local a = 0.3
    x, y, z = u[1], u[2], u[3]

    du[1] = -x * y/(1 + x)
    du[2] = x * y/(1 + x) - a * y
    du[3] = a * y * y
    return du
end
```

Observe that the terms `x * y` can be factored out into a new auxiliary variable
`aux`, and all intermediate operations can be arranged to only involve two arguments,
using parentheses:

```julia
@taylorize function g!(du, u, params, t)
    local a = 0.3
    x, y, z = u[1], u[2], u[3]

    num = x * y
    den = 1 + x
    aux = num/den
    du[1] = -aux
    du[2] = aux - a * (y * y)
    du[3] = a * (y * y)
    return du
end
```

### How are solutions obtained with Taylor models methods plotted?

Flowpipes computed using algorithm `TMJets` (or its variations),
use Taylor model reach-set representations (`TaylorModelReachSet`),
which define an implicit set in time and in space. Since exact visualization of
such objects is difficult (and often unnecessary), we resort to an outer approximation
with simpler sets. Either for plotting or performing set-based operations, we
can *overapproximate* a `TaylorModelReachSet` with other set representations -- usually,
convex sets such as boxes or zonotopes--. The command `overapproximate(sol, Zonotope)`
applies `overapproximate(Ri, Zonotope)` for each reach-set `Ri` in the solution `sol`.

By default, when plotting the solution obtained with such solvers, the zonotopic
overapproximation of the flowpipe is used, with a single zonotope
per Taylor model reach-set. Such approximation, while it is generally coarse,
is often sufficient for visualization purposes.

### Equations with constant terms (`BoundsError`)

Equations that involve constant terms may give a `BoundsError`. This is a known bug
(cf. issue [#179](https://github.com/JuliaReach/ReachabilityAnalysis.jl/issues/179))
and it is related to cases in which the update rule for the right-hand side does not
have the expected coefficient type. The current solution is to change terms
like `du[1] = 1.0` into `du[1] = 1.0 + zero(u[1])`, i.e. let Julia's promotion mechanism
take care by adding the given numeric constant with the zero element of the type of `u`.

**Example.** Consider the function `f!`:

```julia
@taylorize function f!(du, u, p, t)
    du[1] = u[3]^3 - u[2] + u[4]
    du[2] = u[3]
    du[3] = 2.0
    du[4] = u[4]
    return du
end
```
Integrating this function will likely fail with a `BoundsError`. However, we can
re-write it in this way:

```julia
@taylorize function f!(du, u, p, t)
    local two = 2.0 + zero(u[1])
    du[1] = u[3]^3 - u[2] + u[4]
    du[2] = u[3]
    du[3] = two
    du[4] = u[4]
    return du
end
```
