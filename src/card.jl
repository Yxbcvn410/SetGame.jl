CARD_AR = 1.35

@enum CardColor begin
    GREEN
    RED
    PURPLE
end

rgb(c::CardColor) = c == GREEN ? (0, 0.4, 0) :
                    c == RED ? (0.8, 0, 0) : (0.5, 0, 0.5)

@enum CardFill begin
    SOLID
    STRIPES
    NONE
end

@enum CardShape begin
    RHOMBUS
    OVAL
    SNAKE
end

struct Card
    Shape::CardShape
    Fill::CardFill
    Color::CardColor
    Count::Int
    function Card(shape, fill, color, count)
        @assert 1 ≤ count ≤ 3 "Invalid shape count"
        return new(shape, fill, color, count)
    end
end

function draw_shape_outline(ctx, shape::CardShape)
    if shape == RHOMBUS
        polygon(ctx, [Vec2(0, 50), Vec2(50, 0), Vec2(100, 50), Vec2(50, 100)])
    elseif shape == OVAL
        circle(ctx, 50, 50, 50)
    elseif shape == SNAKE
        x0, y0 = (80, 8)
        x1, y1 = (95, 90)
        move_to(ctx, x0, y0)
        for _ in 1:2
            curve_to(ctx, x0 + 40, y0 + 20, x1 - 80, y1 - 20, x1, y1)
            curve_to(ctx, x1 + 20, y1 + 5, 100 - x0 + 30, 100 - y0 + 15, 100 - x0, 100 - y0)
            rotate(ctx, π)
            translate(ctx, -100, -100)
        end
    end
end

function get_striped_surface(color::CardColor)
    s = CairoRGBSurface(100, 100)
    ctx = CairoContext(s)
    rectangle(ctx, 0, 0, 100, 100)
    set_source_rgb(ctx, 1, 1, 1)
    fill(ctx)
    for i in 0:5:100
        move_to(ctx, 0, i)
        line_to(ctx, 100, i)
    end
    set_source_rgb(ctx, rgb(color)...)
    set_line_width(ctx, 2)
    stroke(ctx)
    return s
end

function draw_card(ctx, card::Card; lw = 2)
    translate(ctx, 105 / 2 * (3 - card.Count) + 10, 10)
    for _ in 1:card.Count
        new_sub_path(ctx)
        draw_shape_outline(ctx, card.Shape)
        if card.Fill == STRIPES
            set_source_surface(ctx, get_striped_surface(card.Color))
            fill_preserve(ctx)
        end
        set_source_rgb(ctx, rgb(card.Color)...)
        if card.Fill == SOLID
            fill(ctx)
        else
            set_line_width(ctx, lw)
            stroke(ctx)
        end
        translate(ctx, 105, 0)
    end
    translate(ctx, -105 / 2 * (3 - card.Count) - 10 - 105 * card.Count, -10)
end
