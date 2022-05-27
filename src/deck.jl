include("card.jl")

import Random: shuffle, shuffle!
import Base: length, size, getindex

check_set(c1::Card, c2::Card, c3::Card) =
    (c1.Color == c2.Color == c3.Color || c1.Color != c2.Color != c3.Color != c1.Color) &&
    (c1.Fill == c2.Fill == c3.Fill || c1.Fill != c2.Fill != c3.Fill != c1.Fill) &&
    (c1.Shape == c2.Shape == c3.Shape || c1.Shape != c2.Shape != c3.Shape != c1.Shape) &&
    (c1.Count == c2.Count == c3.Count || c1.Count != c2.Count != c3.Count != c1.Count) &&
    (c1 != c2)

function find_set(cards::AbstractArray{Card})
    l = length(cards)
    for i in 1:l, j in i:l, k in j:l
        if check_set(cards[i], cards[j], cards[k])
            return [i, j, k]
        end
    end
    return nothing
end

const ALL_CARDS = [Card(sh, f, col, ct)
    for sh in instances(CardShape)
    for f in instances(CardFill)
    for col in instances(CardColor)
    for ct in 1:3]

struct Deck
    on_table::Vector{Card}
    deck::Vector{Card}
    found_sets::Vector{Card}
    function Deck()
        inst = new(Card[], copy(ALL_CARDS), Card[])
        shuffle!(inst)
        return inst
    end
end

function shuffle!(d::Deck)
    append!(d.deck, splice!(d.found_sets, 1:length(d.found_sets)))
    append!(d.deck, splice!(d.on_table, 1:length(d.on_table)))
    shuffle!(d.deck)
    append!(d.on_table, splice!(d.deck, 1:12))
    while find_set(d.on_table) === nothing
        append!(d.on_table, splice!(d.deck, 1:3))
    end
    return d
end

check_set(deck::Deck, i::Int, j::Int, k::Int) = check_set(deck.on_table[[i, j, k]]...)

function take_set!(deck::Deck, i::Int, j::Int, k::Int)
    append!(deck.found_sets, deck.on_table[[i, j, k]])
    if length(deck.on_table) ≥ 12 + 3 &&
        find_set([deck.on_table[o] for o in 1:length(deck.on_table) if o ∉ (i, j, k)]) !== nothing
        splice!(deck.on_table, (i, j, k))
        return
    end
    deck.on_table[i], deck.on_table[j], deck.on_table[k] = splice!(deck.deck, 1:3)
    while !isempty(deck.deck) && find_set(deck.on_table) === nothing
        append!(deck.on_table, splice!(deck.deck, 1:3))
    end
end

function shuffle_found!(deck::Deck)
    shuffle!(deck.found_sets)
    append!(deck.deck, splice!(deck.found_sets, 1:length(deck.found_sets)))
    while find_set(deck.deck) === nothing
        append!(deck.on_table, splice!(deck.deck, 1:3))
    end
end

length(d::Deck) = length(d.on_table)
size(deck::Deck) = (3, Int(length(deck.on_table) / 3))
getindex(deck::Deck, i, j) = deck.on_table[i + (j - 1) * 3]
getindex(deck::Deck, i) = deck.on_table[i]
