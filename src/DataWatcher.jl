module DataWatcher

using UnicodePlots
using JLD2
using FileIO

export DataWriter, data_watch, data_view


"""
    plot(x; name, kwargs)

Description
===========

Plots a vector of scalars.

Usage
=====

- `plot(x::AbstractVector; name::String="", kwargs)`

Arguments
=========

- **`x`** : Vector of scalars to plot.
- **`name`** : Optional. What to call `x`. Default "".
- **`kwargs`** : See `? UnicodePlots.lineplot` for all keyword arguments.

Returns
=======

    `nothing`
"""
function plot(x::AbstractVector; name::String="", kwargs...)
    last_val = round(x[end]; digits=3)
    if !(:name in keys(kwargs))
        kwargs = (name="$(last_val)", kwargs...)
    end
    plt = lineplot(x; kwargs...)
    annotate!(plt, :b, "$(name)")
end

"""
  get_terminal_size()

Description
===========

Get the number of columns and rows in the current terminal.

Returns
=======

The columns and rows of the current terminal of type `(Int, Int)`
"""
function get_terminal_size()
    cols = chomp(read(`tput cols`, String))
    cols = tryparse(Int, cols)
    rows = chomp(read(`tput lines`, String))
    rows = tryparse(Int, rows)
    return (cols, rows)
end


"""
    safe_load(path)

Description
===========

Tries to load data from path and retries if there is an error.

Usage
=====

    safe_load(path)

Arguments
=========

- **`path`** : The path to the history file.

Returns
=======

A dictionary of variable names to values of
type `Dict{String, AbstractVector}`
"""
function safe_load(path::String)
    local printed = false
    while true
        try
            data = load(path)
            return data
        catch ex
            if isa(ex, InterruptException)
                throw(ex)
            end
            if printed == false
                Base.run(`clear`)
                printed = true
                print("There's nothing here yet.")
            end
        end
    end
end


"""
    data_watch(path; interval=5)

Description
===========

Iteratively updates the plots from data at path, every interval seconds.

Usage
=====

    data_watch(path; interval=5)

Arguments
=========

- **`path`** : Path to the history file.
- **`interval`** : Optional. How often to update the plots in seconds.

Returns
=======

    nothing

"""
function data_watch(path::String; interval::Real=5)
    # Makes SIGINT catchable when running as a script.
    ccall(:jl_exit_on_sigint, Nothing, (Cint,), 0)

    if (interval < 1)
        println("Setting interval=1 to avoid bus error...")
        interval = 1
    end

    cols, rows = get_terminal_size()

    while true
        try
            hist = safe_load(path)
            i = 1
            Base.run(`clear`)
            height = Int(floor(rows / length(hist)))
            io = IOBuffer()
            for (key, val) in hist
                plt_color = UnicodePlots.color_cycle[i]
                plt = plot(val; name="$(key)",
                           width=cols-20, height=height-4,
                           color=plt_color)
                i += 1
                println(IOContext(io, :color => true), plt)
            end
            print(String(take!(io)))
            sleep(interval)
        catch ex
            if isa(ex, InterruptException)
                Base.run(`clear`)
                return
            else
                throw(ex)
            end
        end
    end
end


"""
    data_view(path)

Description
===========

Simply creates plots of the data at path and prints them to the terminal.

Usage
=====

    data_view(path)

Arguments
=========

- **`path`** : Path to the history file.

Returns
=======

    nothing
"""
function data_view(path::String)
    cols, rows = get_terminal_size()
    hist = safe_load(path)
    height = Int(floor(rows / length(hist)))
    hist = safe_load(path)
    io = IOBuffer()
    i = 1
    for (key, val) in hist
        plt_color = UnicodePlots.color_cycle[i]
        plt = plot(val; name="$(key)", width=cols-20,
                   height=height-4, color=plt_color)
        i += 1
        println(IOContext(io, :color => true), plt)
    end
    print(String(take!(io)))
end

"""
    DataWriter(;file, data)

Description
===========

A simple struct that holds data and writes the data to the specified
file when called.

Usage
=====

    DataWriter(; file="writer.jld2", data=Dict{String,AbstractVector}())

Arguments
=========

- **`file`** : Optional. File name to which to write the data.
- **`data`** : Optional. Dict of data points to initialize with.

Methods
=======

    - `(w::DataWriter)(val::Real, name::String)`

Examples
========

```julia_repl
    writer = DataWriter("out.jld2")
    for i=1:5
        loss = 1 / i
        writer(loss, "Training Loss")
    end
```
    
"""
mutable struct DataWriter
    file::String
    data::Dict
    function DataWriter(file="writer.jld2", data=Dict()) 
        Base.Filesystem.touch(file)
        new(file, data)
    end
end

function (w::DataWriter)(val::Real, name::String)
    try
        append!(w.data[name], val)
    catch ex
        if isa(ex, KeyError)
            w.data[name] = typeof(val)[]
            append!(w.data[name], val)
        else
            throw(ex)
        end
    end
    save(w.file, w.data)
end

end # module
