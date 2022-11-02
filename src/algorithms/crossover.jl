# ==================
# Genetic algorithms
# ==================

"""
    identity(v1, v2)

Returns the same parameter individuals `v1` and `v2` as an offspring pair.
"""
identity(v1::T, v2::T; kwargs...) where {T<:AbstractVector} = (v1, v2)
identity(v1::T, v2::T; kwargs...) where {T<:AbstractIndividual} = (v1, v2)

# Binary crossovers
# -----------------

"""
    SPX(v1, v2)

Single point crossover between `v1` and `v2` individuals.
"""
function SPX(
    v1::T,
    v2::T;
    rng::AbstractRNG = Random.default_rng(),
) where {T<:AbstractVector}
    l = length(v1)
    c1 = copy(v1)
    c2 = copy(v2)
    pos = rand(rng, 1:l)
    for i = pos:l
        vswap!(c1, c2, i)
    end
    return c1, c2
end
SPX(v1::T, v2::T; rng::AbstractRNG = Random.default_rng()) where {T<:AbstractIndividual} = 
    map(T, SPX(variables(v1), variables(v2), rng=rng))

"""
    TPX(v1, v2)

Two point crossover between `v1` and `v2` individuals.
"""
function TPX(
    v1::T,
    v2::T;
    rng::AbstractRNG = Random.default_rng(),
) where {T<:AbstractVector}
    l = length(v1)
    c1 = copy(v1)
    c2 = copy(v2)
    from, to = rand(rng, 1:l, 2)
    from, to = from > to ? (to, from) : (from, to)
    for i = from:to
        vswap!(c1, c2, i)
    end
    return c1, c2
end
TPX(v1::T, v2::T; rng::AbstractRNG = Random.default_rng()) where {T<:AbstractIndividual} = 
    map(T, TPX(variables(v1), variables(v2), rng=rng))

"""
    SHFX(v1, v2)

Shuffle crossover between the parents `v1` and `v2` that performs recombination similar to [`SPX`](@ref) preliminary shuffling these parents.
"""
function SHFX(
    v1::T,
    v2::T;
    rng::AbstractRNG = Random.default_rng(),
) where {T<:AbstractVector}
    l = length(v1)
    # shuffle and perform 1-point XO
    prm = randperm(rng, l)
    tmp1, tmp2 = SPX(view(v1, prm), view(v2, prm), rng = rng)
    # unshuffle offspring
    c1, c2 = similar(tmp1), similar(tmp2)
    for (i, j) in enumerate(prm)
        c1[j] = tmp1[i]
        c2[j] = tmp2[i]
    end
    return c1, c2
end
SHFX(v1::T, v2::T; rng::AbstractRNG = Random.default_rng()) where {T<:AbstractIndividual} = 
    map(T, SHFX(variables(v1), variables(v2), rng=rng))

"""
    UX(v1, v2)

Uniform crossover between `v1` and `v2` individuals.
"""
function UX(v1::T, v2::T; rng::AbstractRNG = Random.default_rng()) where {T<:AbstractVector}
    l = length(v1)
    c1 = copy(v1)
    c2 = copy(v2)
    xch = rand(rng, Bool, l)
    for i = 1:l
        if xch[i]
            vswap!(c1, c2, i)
        end
    end
    return c1, c2
end
UX(v1::T, v2::T; rng::AbstractRNG = Random.default_rng()) where {T<:AbstractIndividual} = 
    map(T, UX(variables(v1), variables(v2), rng=rng))

"""
    BINX(Cr::Real=0.5)

Returns a uniform (binomial) crossover function, see [Recombination Interface](@ref), function with the probability `Cr` [^2].

The crossover probability value must be in unit interval, ``Cr \\in [0,1]``.
"""
function BINX(Cr::Real = 0.5)
    function binxvr(
        v1::T,
        v2::T;
        rng::AbstractRNG = Random.default_rng(),
    ) where {T<:AbstractVector}
        l = length(v1)
        c1 = copy(v1)
        c2 = copy(v2)
        j = rand(rng, 1:l)
        for i in (((1:l) .+ j .- 2) .% l) .+ 1
            if rand(rng) <= Cr
                vswap!(c1, c2, i)
            end
        end
        return c1, c2
    end
    function binxvr(
        v1::T,
        v2::T;
        rng::AbstractRNG = Random.default_rng(),
    ) where {T<:AbstractIndividual}
        c1, c2 = binxvr(variables(v1), variables(v2), rng=rng)
        return T(c1), T(c2)
    end
    return binxvr
end

"""
    EXPX(Cr::Real=0.5)

Returns an exponential crossover function, see [Recombination Interface](@ref), function with the probability `Cr` [^2].

The crossover probability value must be in unit interval, ``Cr \\in [0,1]``.
"""
function EXPX(Cr::Real = 0.5)
    function expxvr(
        v1::T,
        v2::T;
        rng::AbstractRNG = Random.default_rng(),
    ) where {T<:AbstractVector}
        l = length(v1)
        c1 = copy(v1)
        c2 = copy(v2)
        j = rand(rng, 1:l)
        switch = true
        for i in (((1:l) .+ j .- 2) .% l) .+ 1
            i == j && continue
            if switch && rand(rng) <= Cr
                c1[i] = v1[i]
            else
                switch = false
                c1[i] = v2[i]
            end
        end
        return c1, copy(c1)
    end
    function expxvr(
        v1::T,
        v2::T;
        rng::AbstractRNG = Random.default_rng(),
    ) where {T<:AbstractIndividual}
        map(T, expxvr(variables(v1), variables(v2), rng=rng))
    end
    return expxvr
end

"""
    BSX(k::Int)

Binary Subset Crossover[^7]. Produces an offspring by first pooling the unique
items of the two parents, and then creating each offspring by sampling without 
replacement at most `k` elements from the pool of items.
"""
function BSX(k::Int)
    function BSX(
        v1::T,
        v2::T;
        rng::AbstractRNG = Random.default_rng(),
    ) where {T<:AbstractVector{Bool}}
        l = length(v1) # get number of available elements
        pooled = findall(v1 .| v2) # pool parents selections
        K = min(k, length(pooled)) # cannot sample more than the items in pool
        c1 = falses(l) # init child 1
        c2 = falses(l) # init child 2
        c1[shuffle(rng, pooled)[1:K]] .= true # fill child 1 with sample from pool w/o replacement
        c2[shuffle(rng, pooled)[1:K]] .= true # fill child 2 with sample from pool w/o replacement
        return c1, c2
    end
    function BSX(
        v1::T,
        v2::T;
        rng::AbstractRNG = Random.default_rng(),
    ) where {T<:AbstractIndividual}
        map(T, BSX(variables(v1), variables(v2), rng=rng))
    end
    return BSX
end


# Real valued crossovers
# ----------------------

"""
    DC(v1, v2)

Returns a randomly assembled offspring and its inverse from the elements of parents `v1` and `v2`.
"""
function DC(v1::T, v2::T; rng::AbstractRNG = Random.default_rng()) where {T<:AbstractVector}
    l = length(v1)
    c1 = similar(v1)
    c2 = similar(v2)
    sltc = rand(rng, Bool, 2, l)
    for i = 1:l
        c1[i] = sltc[1, i] ? v1[i] : v2[i]
        c2[i] = sltc[2, i] ? v2[i] : v1[i]
    end
    return c1, c2
end
DC(v1::T, v2::T; rng::AbstractRNG = Random.default_rng()) where {T<:AbstractIndividual} = 
    map(T, DC(variables(v1), variables(v2), rng=rng))

"""
    WAX(w::Vector{<:Real})(v1, v2)

Returns a weighted average recombination operation, see [Recombination Interface](@ref), which generate an offspring as weighted average of the parents `v1` and `v2` with the weights `w`.
"""
function WAX(w::Vector{<:Real})
    function wavexvr(
        v1::T,
        v2::T;
        rng::AbstractRNG = Random.default_rng(),
    ) where {T<:AbstractVector}
        c1 = (v1 + v2) ./ w
        return c1, copy(c1)
    end
    function wavexvr(
        v1::T,
        v2::T;
        rng::AbstractRNG = Random.default_rng(),
    ) where {T<:AbstractIndividual}
        map(T, wavexvr(variables(v1), variables(v2), rng=rng))
    end
    return wavexvr
end

"""
    AX(v1, v2)

Average crossover generates an offspring by taking average of the parents `v1` and `v2`. 
"""
function AX(v1::T, v2::T; rng::AbstractRNG = Random.default_rng()) where {T<:AbstractVector}
    c1 = (v1 + v2) ./ 2
    return c1, copy(c1)
end
AX(v1::T, v2::T; rng::AbstractRNG = Random.default_rng()) where {T<:AbstractIndividual} = 
    map(T, AX(variables(v1), variables(v2), rng=rng))

"""
    IC(d::Real=0.0)

Returns an extended intermediate recombination operation, see [Recombination Interface](@ref), which generates offspring `u` and `v` as

- ``u_i = x_i + \\alpha_i (y_i - x_i)``
- ``v_i = y_i + \\alpha_i (x_i - y_i)``

where ``\\alpha_i`` is chosen uniform randomly in the interval ``[-d;d+1]``.

"""
function IC(d::Real = 0.0)
    function intermxvr(
        v1::T,
        v2::T;
        rng::AbstractRNG = Random.default_rng(),
    ) where {T<:AbstractVector}
        l = length(v1)
        α = (1.0 + 2d) * rand(rng, l) .- d
        c1 = v2 .+ α .* (v1 - v2)
        α = (1.0 + 2d) * rand(rng, l) .- d
        c2 = v1 .+ α .* (v2 - v1)
        return c1, c2
    end
    function intermxvr(
        v1::T,
        v2::T;
        rng::AbstractRNG = Random.default_rng(),
    ) where {T<:AbstractIndividual}
        map(T, intermxvr(variables(v1), variables(v2), rng=rng))
    end
    return intermxvr
end

"""
    LC(d::Real=0.0)

Returns a extended line recombination operation, see [Recombination Interface](@ref), which generates offspring `u` and `v` as

- ``u_i = x_i + \\alpha (y_i - x_i)``
- ``v_i = y_i + \\alpha (x_i - y_i)``

where ``\\alpha`` is chosen uniform randomly in the interval ``[-d;d+1]``.

"""
function LC(d::Real = 0.0)
    function linexvr(
        v1::T,
        v2::T;
        rng::AbstractRNG = Random.default_rng(),
    ) where {T<:AbstractVector}
        α1, α2 = (1.0 + 2d) * rand(rng, 2) .- d
        c1 = v2 .+ α2 * (v1 - v2)
        c2 = v1 .+ α1 * (v2 - v1)
        return c1, c2
    end
    function linexvr(
        v1::T,
        v2::T;
        rng::AbstractRNG = Random.default_rng(),
    ) where {T<:AbstractIndividual}
        map(T, linexvr(variables(v1), variables(v2), rng=rng))
    end
    return linexvr
end

"""
    HX(x, y)

Heuristic crossover (HX) recombination operation[^3] generates offspring `u` and `v` as

- ``u = x + r (x - y)``
- ``v = y + r (y - x)``

where ``r`` is chosen uniform randomly in the interval ``[0;1)``.
"""
function HX(v1::T, v2::T; rng::AbstractRNG = Random.default_rng()) where {T<:AbstractVector}
    c1 = v1 .+ rand(rng) * (v1 .- v2)
    c2 = v2 .+ rand(rng) * (v2 .- v1)
    return c1, c2
end
HX(v1::T, v2::T; rng::AbstractRNG = Random.default_rng()) where {T<:AbstractIndividual} = 
    map(T, HX(variables(v1), variables(v2), rng=rng))

"""
    LX(μ::Real = 0.0, b::Real = 0.2)

Returns a Laplace crossover (LX) recombination operation[^4], see [Recombination Interface](@ref).
"""
function LX(μ::Real = 0.0, b::Real = 0.2) # location μ, scale b > 0
    function lxxvr(
        v1::T,
        v2::T;
        rng::AbstractRNG = Random.default_rng(),
    ) where {T<:AbstractVector}
        u = rand(rng)
        β = u > 0.5 ? μ + b * log(u) : μ - b * log(u)
        S = β * abs.(v1 - v2)
        c1 = v1 + S
        c2 = v2 + S
        return c1, c2
    end
    function lxxvr(
        v1::T,
        v2::T;
        rng::AbstractRNG = Random.default_rng(),
    ) where {T<:AbstractIndividual}
        map(T, lxxvr(variables(v1), variables(v2), rng=rng))
    end
    return lxxvr
end

"""
    MILX(μ::Real = 0.0, b_real::Real = 0.15, b_int::Real = 0.35)

Returns a mixed integer Laplace crossover (MI-LX) recombination operation[^5], see [Recombination Interface](@ref).
"""
function MILX(μ::Real = 0.0, b_real::Real = 0.15, b_int::Real = 0.35) # location μ, scale b > 0
    function milxxvr(
        v1::T,
        v2::T;
        rng::AbstractRNG = Random.default_rng(),
    ) where {T<:AbstractVector}
        @assert all([typeof(a) == typeof(b) for (a, b) in zip(v1, v2)]) "Types of variables in vectors do not match"
        l = length(v1)
        U, R = rand(rng, l), rand(rng, l)
        B = (isa(x, Integer) ? b_int : b_real for x in v1)
        βs = broadcast((u, r, b) -> r > 0.5 ? μ + b * log.(u) : μ - b * log.(u), U, R, B)
        S = βs .* abs.(v1 - v2)
        c1 = v1 + S
        c2 = v2 + S
        return c1, c2
    end
    function milxxvr(
        v1::T,
        v2::T;
        rng::AbstractRNG = Random.default_rng(),
    ) where {T<:AbstractIndividual}
        map(T, milxxvr(variables(v1), variables(v2), rng=rng))
    end
    return milxxvr
end

"""
    SBX(pm::Real = 1.0, η::Integer = 20)

Returns a Simulated Binary Crossover (SBX) recombination operation, see [Recombination Interface](@ref),
with the mutation probability `pm` of the recombinant component, and is the crossover distribution index `η`[^6].
"""
function SBX(; pm::Real = 0.5, η::Integer = 20)
    function sbx(
        v1::T,
        v2::T;
        rng::AbstractRNG = Random.default_rng(),
    ) where {T<:Real}
        u = rand(rng)
        if u <= 0.5
            β = (2u) ^ (1 / (η + 1))
        else
            β = (2 - 2u) ^ (-1 / (η + 1))
        end
        β = β * (-1) ^ round(rand(rng))
        c1 = (v1 + v2) / 2 + β * (v1 - v2) / 2
        c2 = (v1 + v2) / 2 - β * (v1 - v2) / 2
        return c1, c2
    end
    function sbx(
        v1::T,
        v2::T;
        rng::AbstractRNG = Random.default_rng(),
    ) where {T<:AbstractVector}
        d = length(v1)
        pm = isnan(pm) ? 1 / d : pm
        c1 = copy(v1)
        c2 = copy(v2)
        for i = 1:d
            if rand(rng) < pm
                c1[i], c2[i] = sbx(v1[i], v2[i], rng=rng) 
            end
        end
        c1, c2
    end
    function sbx(
        v1::T,
        v2::T;
        rng::AbstractRNG = Random.default_rng(),
    ) where {T<:AbstractIndividual}
        map(T, sbx(variables(v1), variables(v2), rng=rng))
    end
    return sbx
end


# Combinatorial crossovers
# ------------------------

"""
    PMX(v1, v2)

Partially mapped crossover which maps ordering and values information from
the parents `v1` and `v2` to  the offspring. A portion of one parent is mapped onto
a portion of the other parent string and the remaining information is exchanged.
"""
function PMX(
    v1::T,
    v2::T;
    rng::AbstractRNG = Random.default_rng(),
) where {T<:AbstractVector}
    s = length(v1)
    from, to = rand(rng, 1:s, 2)
    from, to = from > to ? (to, from) : (from, to)
    c1 = similar(v1)
    c2 = similar(v2)

    # Swap
    c1[from:to] = v2[from:to]
    c2[from:to] = v1[from:to]

    # Fill in from parents
    for i in vcat(1:from-1, to+1:s)
        # Check conflicting offspring
        in1 = inmap(v1[i], c1, from, to)
        if in1 == 0
            c1[i] = v1[i]
        else
            tmpin = in1
            while tmpin > 0
                tmpin = inmap(c2[in1], c1, from, to)
                in1 = tmpin > 0 ? tmpin : in1
            end
            c1[i] = v1[in1]
        end

        in2 = inmap(v2[i], c2, from, to)
        if in2 == 0
            c2[i] = v2[i]
        else
            tmpin = in2
            while tmpin > 0
                tmpin = inmap(c1[in2], c2, from, to)
                in2 = tmpin > 0 ? tmpin : in2
            end
            c2[i] = v2[in2]
        end
    end
    return c1, c2
end
PMX(v1::T, v2::T; rng::AbstractRNG = Random.default_rng()) where {T<:AbstractIndividual} = 
    map(T, PMX(variables(v1), variables(v2), rng=rng))

"""
    OX1(v1, v2)

Order crossover constructs an offspring by choosing a substring of one parent
and preserving the relative order of the elements of the other parent.
"""
function OX1(
    v1::T,
    v2::T;
    rng::AbstractRNG = Random.default_rng(),
) where {T<:AbstractVector}
    s = length(v1)
    from, to = rand(rng, 1:s, 2)
    from, to = from > to ? (to, from) : (from, to)
    c1 = zero(v1)
    c2 = zero(v2)
    # Swap
    c1[from:to] = v2[from:to]
    c2[from:to] = v1[from:to]
    # Fill in from parents
    k = to + 1 > s ? 1 : to + 1 #child1 index
    j = to + 1 > s ? 1 : to + 1 #child2 index
    for i in vcat(to+1:s, 1:from-1)
        while in(v1[k], c1)
            k = k + 1 > s ? 1 : k + 1
        end
        c1[i] = v1[k]
        while in(v2[j], c2)
            j = j + 1 > s ? 1 : j + 1
        end
        c2[i] = v2[j]
    end
    return c1, c2
end
OX1(v1::T, v2::T; rng::AbstractRNG = Random.default_rng()) where {T<:AbstractIndividual} = 
    map(T, OX1(variables(v1), variables(v2), rng=rng))

"""
    CX(v1, v2)

Cycle crossover creates an offspring from the parents `v1` and `v2` such that
every position is occupied by a corresponding element from one of the parents.
"""
function CX(v1::T, v2::T; kwargs...) where {T<:AbstractVector}
    s = length(v1)
    c1 = zero(v1)
    c2 = zero(v2)
    c1i = fill(true, length(v1))
    c2i = fill(true, length(v2))
    Z = zero(eltype(T))

    f1 = true #switch
    k = 1
    while k > 0
        idx = k
        if f1
            #cycle from v1
            while c1i[idx]
                c1[idx] = v1[idx]
                c2[idx] = v2[idx]
                c1i[idx] = false
                c2i[idx] = false
                idx = inmap(v2[idx], v1, 1, s)
            end
        else
            #cycle from v2
            while c2i[idx]
                c1[idx] = v2[idx]
                c2[idx] = v1[idx]
                c1i[idx] = false
                c2i[idx] = false
                idx = inmap(v1[idx], v2, 1, s)
            end
        end
        f1 ⊻= true
        k = inmap(true, c2i, 1, s)
    end
    return c1, c2
end
CX(v1::T, v2::T; kwargs...) where {T<:AbstractIndividual} = 
    map(T, CX(variables(v1), variables(v2); kwargs...))

"""
    OX2(v1, v2)

Order-based crossover selects at random several positions in the parent `v1`, and
the order of the elements in the selected positions of the parent `v1` is imposed on
the parent `v2`.
"""
function OX2(
    v1::T,
    v2::T;
    rng::AbstractRNG = Random.default_rng(),
) where {T<:AbstractVector}
    s = length(v1)
    c1 = copy(v1)
    c2 = copy(v2)
    Z = zero(eltype(T))

    for i = 1:s
        if rand(rng, Bool)
            idx1 = inmap(v2[i], v1, 1, s)
            idx2 = inmap(v1[i], v2, 1, s)
            c1[idx1] = Z
            c2[idx2] = Z
        end
    end

    for i = 1:s
        if !in(v2[i], c1)
            tmpin = inmap(Z, c1, 1, s)
            c1[tmpin] = v2[i]
        end
        if !in(v1[i], c2)
            tmpin = inmap(Z, c2, 1, s)
            c2[tmpin] = v1[i]
        end
    end
    return c1, c2
end
OX2(v1::T, v2::T; rng::AbstractRNG = Random.default_rng()) where {T<:AbstractIndividual} = 
    map(T, OX2(variables(v1), variables(v2), rng=rng))

"""
    POS(v1, v2)

Position-based crossover is a modification of the [`OX1`](@ref) operator.
It selects a random set of positions in the parents `v1` and `v2`, then imposes
the position of the selected elements of one parent on the corresponding elements
of the other parent.
"""
function POS(
    v1::T,
    v2::T;
    rng::AbstractRNG = Random.default_rng(),
) where {T<:AbstractVector}
    s = length(v1)
    c1 = zero(v1)
    c2 = zero(v2)
    Z = zero(eltype(T))

    for i = 1:s
        if rand(rng, Bool)
            c1[i] = v2[i]
            c2[i] = v1[i]
        end
    end

    for i = 1:s
        if !in(v1[i], c1)
            tmpin = inmap(Z, c1, 1, s)
            c1[tmpin] = v1[i]
        end
        if !in(v2[i], c2)
            tmpin = inmap(Z, c2, 1, s)
            c2[tmpin] = v2[i]
        end
    end
    return c1, c2
end
POX(v1::T, v2::T; rng::AbstractRNG = Random.default_rng()) where {T<:AbstractIndividual} = 
    map(T, POX(variables(v1), variables(v2), rng=rng))

"""
    SSX(v1, v2)

Subset crossover operator creates new offspring by pooling the unique indices of
the two parent vectors `v1` and `v2`, and then sampling a set of unique indices
from this pool, uniformly at random.
"""
function SSX(
    v1::T,
    v2::T;
    rng::AbstractRNG = Random.default_rng(),
) where {T<:AbstractVector}
    l = length(v1)
    pool = unique([v1; v2])
    p = length(pool)
    c1, c2 = if l <= p
        pool[randperm(p)[1:l]], pool[randperm(p)[1:l]]
    else
        rand(pool, l), rand(pool, l)
    end
    return c1, c2
end
SSX(v1::T, v2::T; rng::AbstractRNG = Random.default_rng()) where {T<:AbstractIndividual} = 
    map(T, SSX(variables(v1), variables(v2), rng=rng))