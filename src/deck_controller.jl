include("deck.jl")

using Dates, DataFrames, CSV

const CARD_PROPS = (:Shape, :Fill, :Color, :Count)
const TIME_FORMAT = dateformat"H h M \m S \s"
const data = DataFrame(
    :Count => Int[],
    :Count_1 => Int[],
    :Count_2 => Int[],
    :Count_3 => Int[],
    :Shape => Int[],
    :Shape_RHOMBUS => Int[],
    :Shape_OVAL => Int[],
    :Shape_SNAKE => Int[],
    :Fill => Int[],
    :Fill_SOLID => Int[],
    :Fill_STRIPES => Int[],
    :Fill_NONE => Int[],
    :Color => Int[],
    :Color_GREEN => Int[],
    :Color_RED => Int[],
    :Color_PURPLE => Int[],
)

function get_set_context(deck::Deck, i::Int, j::Int, k::Int)
    ctx = Dict()
    for property in CARD_PROPS
        prop_variants = [property == (:Count) ?
        (1:3) : getproperty(deck[i], property) |> typeof |> instances]
        prop_vals = getproperty.(deck.on_table, property)
        for v in prop_vals
            key = Symbol(string(property) * "_" * string(v))
            push!(ctx, key => count(==(v), prop_vals))
        end
        set_type = (prop_vals[i] == prop_vals[j] == prop_vals[k]) ?
        (Int(prop_vals[i])) : -1
        push!(ctx, property => set_type)
    end
    return ctx
end

@enum GameLim begin
    INFINITE
    FIND_ALL
    FIND_TEN
end

struct GameMode
    limit::GameLim
    shuffle::Bool
end

mutable struct DeckController
    deck::Deck
    set_found_timestamp::DateTime
    game_start_timestamp::DateTime
    game_end_timestamp::Union{DateTime, Nothing}
    is_shuffle::Bool
    counter::Int
    mode::GameMode
    set_is_hint::Bool
    collect_stats::Bool
    function DeckController(d::Deck, m::GameMode)
        new(d, now(), now(), nothing, true, 0, m, false, false)
    end
end

game_active(dc::DeckController) = dc.game_end_timestamp === nothing

function try_take_set!(dc::DeckController, i, j, k)
    if !check_set(dc.deck, i, j, k) || !game_active(dc)
        return false
    end
    if dc.collect_stats
        ctx = get_set_context(dc.deck, i, j, k)
        ctx[:dt] = (now() - dc.set_found_timestamp).value / 1000
        ctx[:isr] = dc.is_shuffle
        ctx[:hint] = dc.set_is_hint
        push!(data, ctx, cols = :union)
    end
    take_set!(dc.deck, i, j, k)
    dc.counter += 1

    if dc.mode.shuffle
        shuffle!(dc.deck)
    end
    dc.is_shuffle = dc.mode.shuffle
    dc.set_found_timestamp = now()
    if dc.mode.limit == FIND_ALL
        if find_set(dc.deck.on_table) === nothing
            dc.game_end_timestamp = now()
        end
    elseif dc.mode.limit == FIND_TEN
        if dc.counter ≥ 10
            dc.game_end_timestamp = now()
        end
    elseif dc.mode.limit == INFINITE
        if dc.deck.deck |> isempty
            shuffle_found!(dc.deck)
        end
    end
    return true
end

function get_summary(dc::DeckController)
    dt2 = dc.game_end_timestamp === nothing ? now() : dc.game_end_timestamp
    t = Dates.format(Time(0) + (dt2 - dc.game_start_timestamp), TIME_FORMAT)
    com = dc.mode.limit == INFINITE ? "/∞" :
            dc.mode.limit == FIND_TEN ? "/10" :
            ", $(length(dc.deck.deck)) cards in deck left"
    return "Sets found: $(dc.counter)$com; Time elapsed: $t"
end

function restart!(dc::DeckController)
    dc.counter = 0
    dc.set_is_hint = false
    dc.game_start_timestamp = dc.set_found_timestamp = now()
    dc.game_end_timestamp = nothing
    shuffle!(dc.deck)
end

function restart!(dc::DeckController, m::GameMode)
    dc.mode = m
    restart!(dc)
end

function mark_hint!(dc::DeckController)
    dc.set_is_hint = true
end
