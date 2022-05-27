include("deck.jl")

using Cairo
import Base: getindex, setindex!, size, length

const GREY_RGB = (0.7, 0.7, 0.7)
const GREEN_RGB = (0, 0.7, 0)
const RED_RGB = (0.8, 0, 0)

mutable struct DeckView
    deck::Deck
    painter::Matrix{NTuple{3, Float64}}
    selected::Matrix{Bool}
    field_frame::GtkAspectFrame
    vertical_layout::Bool
    function DeckView(dc::DeckController, field_grid, vertical_layout)
        inst = new(dc.deck, fill(GREY_RGB, size(dc.deck)), fill(false, size(dc.deck)), field_grid, vertical_layout)
        generate_cards(inst) do x, y
            process_click!(inst, dc, x, y)
        end
        return inst
    end
end

getindex(fw::DeckView, i, j) = fw.selected[i, j]
setindex!(fw::DeckView, v, i, j) = setindex!(fw.selected, v, i, j)
size(fw::DeckView) = size(fw.deck)
length(fw::DeckView) = length(fw.deck)
get_color(fw::DeckView, i, j) = fw.painter[i, j]

function set_layout!(fw::DeckView, dc::DeckController, l::Bool)
    fw.vertical_layout = l
    generate_cards(fw) do x, y
        process_click!(fw, dc, x, y)
    end
end

function process_click!(fw::DeckView, dc::DeckController, x, y)
    if !game_active(dc)
        return
    end
    fw[x, y] = !fw[x, y]
    fw.painter[x, y] = fw[x, y] ? GREEN_RGB : GREY_RGB
    redraw_all(fw)
    selected_idx = [i for i in 1:length(fw) if reshape(fw.selected, (length(fw),))[i]]

    if length(selected_idx) == 3 && try_take_set!(dc, selected_idx...)
        fw.painter = fill(GREY_RGB, size(fw.deck))
        fw.selected = fill(false, size(fw.deck))
        generate_cards(fw) do x, y
            process_click!(fw, dc, x, y)
        end
    end

    if !game_active(dc)
        game_time = Time(0) + (now() - dc.game_start_timestamp)
        info_dialog("Game over.\n You found $(dc.counter) sets in $(Dates.format(game_time, TIME_FORMAT)).\n Restart the game to play again!")
    end
end

function hint_set!(fw::DeckView)
    for idx in find_set(fw.deck.on_table)
        fw.painter[idx] = RED_RGB
        fw.selected[idx] = false
    end
    redraw_all(fw)
end

function generate_cards(click_callback, fw::DeckView)
    r, c = size(fw)
    empty!(fw.field_frame[1])
    set_gtk_property!(fw.field_frame, :ratio,
    fw.vertical_layout ? r * CARD_AR / c : c / CARD_AR / r )
    for x in 1:r, y in 1:c
        canv = @GtkCanvas

        @guarded draw(canv) do _
            ctx = getgc(canv)
            w = width(canv)
            if fw.vertical_layout
                set_coordinates(ctx, BoundingBox(0, 330, 0, 120))
            else
                set_coordinates(ctx, BoundingBox(0, 120, 0, 330))
                rotate(ctx, -π/2)
                translate(ctx, -330, 0)
            end


            draw_card(ctx, fw.deck[x, y], lw = w / 200 * 2)
            rectangle(ctx, 5, 5, 320, 110)
            set_source_rgb(ctx, fw.painter[x, y]...)
            set_line_width(ctx, w / 200 * 4)
            stroke(ctx)
        end

        @guarded signal_connect(canv, "button_press_event") do widget, event
            if event.event_type == 4
                click_callback(x, y)
                draw(widget, false)
            end
            return true
        end

        visible(canv, true)
        if fw.vertical_layout
            fw.field_frame[1][x, y] = canv
        else
            fw.field_frame[1][y, x] = canv
        end
    end
end

function redraw_all(fw)
    for c in fw.field_frame[1]
        draw(c, true)
    end
end
