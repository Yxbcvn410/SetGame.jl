using Gtk, JSON, CSV

const SETTINGS_PATH = "settings.json"
const STATS_PATH = "stats.csv"
const DEFAULT_SETTINGS = Dict(:mode => 0, :shuffle => false, :v_layout => true, :stats => false)

include("deck_controller.jl")
include("deck_view.jl")


function settings_window(confirm_callback, initial_params::Dict = DEFAULT_SETTINGS)
    win = GtkWindow("Settings")
    settings_changed = false
    gr = GtkGrid()
    push!(win, gr)

    function cbox_handler(_...)
        !settings_changed && set_gtk_property!(win, :title, "Settings*")
        settings_changed = true
        initial_params[:mode] = get_gtk_property(game_mode, :active, Int)
        initial_params[:shuffle] = get_gtk_property(game_mode, :active, Bool) && (initial_params[:mode] != 1)
        initial_params[:v_layout] = get_gtk_property(orientation, :active, Int) == 1
        set_gtk_property!(always_shuffle, :sensitive, initial_params[:mode] != 1)
        return
    end

    function switch_handler(widget, event)
        !settings_changed && set_gtk_property!(win, :title, "Settings*")
        settings_changed = true
        set_gtk_property!(widget, :state, event)
        initial_params[:stats] = get_gtk_property(stats_collect, :state, Bool)
        return true
    end

    game_mode = GtkComboBoxText()
    modes = ["Infinite", "Find all", "Find 10"]
    append!(game_mode, modes)
    set_gtk_property!(game_mode, :active, initial_params[:mode])
    signal_connect(cbox_handler, game_mode, :changed)
    gr[1, 1] = GtkLabel("Game mode")
    gr[2, 1] = game_mode

    always_shuffle = GtkCheckButton("Shuffle deck after every set found")
    set_gtk_property!(always_shuffle, :active, initial_params[:shuffle])
    set_gtk_property!(always_shuffle, :sensitive, initial_params[:mode] != 1)
    signal_connect(cbox_handler, always_shuffle, :toggled)
    gr[1:2, 2] = always_shuffle

    orientation = GtkComboBoxText()
    ors = ["Horizontal", "Vertical"]
    append!(orientation, ors)
    set_gtk_property!(orientation, :active, initial_params[:v_layout])
    signal_connect(cbox_handler, orientation, :changed)
    gr[1, 3] = GtkLabel("Field orientation")
    gr[2, 3] = orientation

    stats_collect = Gtk.GtkSwitch()
    set_gtk_property!(stats_collect, :state, initial_params[:stats])
    signal_connect(switch_handler, stats_collect, :state_set)
    gr[1, 4] = GtkLabel("Collect stats")
    gr[2, 4] = GtkBox(:h)
    push!(gr[2, 4], stats_collect)

    confirm_button = GtkButton("Confirm")
    signal_connect(confirm_button, :clicked) do _
        confirm_callback(initial_params)
        hide(win)
    end
    gr[1, 5] = confirm_button

    cancel_button = GtkButton("Cancel")
    signal_connect(cancel_button, :clicked) do _
        hide(win)
    end
    gr[2, 5] = cancel_button

    set_gtk_property!(gr, :column_homogeneous, true)
    set_gtk_property!(gr, :column_spacing, 15)
    set_gtk_property!(gr, :row_spacing, 15)
    set_gtk_property!(gr, :border_width, 10)
    set_gtk_property!(win, :resizable, false)
    set_gtk_property!(win, :modal, true)
    @guarded signal_connect(win, :delete_event) do widget, event
        if settings_changed &&
            ask_dialog("You have unsaved changes. Do you wish to reset them?", "Cancel", "Reset") == 0
            return true
        end
        hide(win)
        return true
    end
    return win
end

function init_settings(path)

    return isfile(path) ? begin
        p = JSON.parsefile(path)
        Dict(k => (string(k) in keys(p) ? p[string(k)] : DEFAULT_SETTINGS[k])
            for k in keys(DEFAULT_SETTINGS))
    end : DEFAULT_SETTINGS
end

function dump_settings(path, settings)
    open(path, "w") do io
        write(io, JSON.json(settings))
    end
end

function julia_main()
    settings = init_settings("settings.json")
    deck = Deck()
    deck_ctl = DeckController(deck, GameMode(GameLim(settings[:mode]), settings[:shuffle]))
    deck_ctl.collect_stats = settings[:stats]

    win = GtkWindow("Set game")
    main_l = GtkBox(:v)
    push!(win, main_l)

    lab = GtkLabel("Click anywhere to start")
    push!(main_l, lab)

    field = GtkGrid()
    set_gtk_property!(field, :height_request, 400)
    set_gtk_property!(field, :width_request, 600)
    set_gtk_property!(field, :column_homogeneous, true)
    set_gtk_property!(field, :column_spacing, 15)
    set_gtk_property!(field, :row_homogeneous, true)
    set_gtk_property!(field, :border_width, 0)
    set_gtk_property!(field, :row_spacing, 15)
    asp = GtkAspectFrame("", 0.5, 0.5, 1/0.6)
    push!(main_l, asp)
    push!(asp, field)
    deck_vw = DeckView(deck_ctl, asp, settings[:v_layout])

    bts = GtkButtonBox(:h)
    hint_button = GtkButton("Hint")
    @guarded signal_connect(hint_button, :clicked) do _
        if game_active(deck_ctl)
            hint_set!(deck_vw)
            mark_hint!(deck_ctl)
        end
    end
    push!(bts, hint_button)

    restart_button = GtkButton("Restart")
    push!(bts, restart_button)
    @guarded signal_connect(restart_button, :clicked) do _
        restart!(deck_ctl)
        generate_cards(deck_vw) do x, y
            process_click!(deck_vw, deck_ctl, x, y)
        end
    end

    settings_button = GtkButton("Settings")
    settings_win = settings_window(settings) do new_settings
        settings = new_settings
        dump_settings(SETTINGS_PATH, settings)
        set_layout!(deck_vw, deck_ctl, settings[:v_layout])
        deck_ctl.collect_stats = settings[:stats]
        deck_ctl.mode = GameMode(GameLim(settings[:mode]), settings[:shuffle])
    end
    hide(settings_win)
    @guarded signal_connect(settings_button, :clicked) do _
        showall(settings_win)
    end
    push!(bts, settings_button)

    stats_button = GtkButton("Stats")
    push!(bts, stats_button)

    set_gtk_property!(bts, :spacing, 10)
    set_gtk_property!(bts, :halign, 3)

    push!(main_l, bts)
    set_gtk_property!(main_l, :border_width, 5)
    set_gtk_property!(main_l, :spacing, 5)
    set_gtk_property!(main_l, :expand, asp, true)
    showall(win)

    t = Timer(0, interval = 0.1) do _...
        set_gtk_property!(lab, :label, get_summary(deck_ctl))
    end

    c = Condition()
    @guarded signal_connect(win, :destroy) do _
        notify(c)
    end
    @async Gtk.gtk_main()
    wait(c)

    if settings[:stats]
        CSV.write(STATS_PATH, data, append = isfile(STATS_PATH))
    end
    return 0
end

julia_main()
