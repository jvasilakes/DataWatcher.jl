using Random
using DataWatcher: DataWriter


ccall(:jl_exit_on_sigint, Nothing, (Cint,), 0)


function generate_sin_cos()
    local x = 1.0
    writer = DataWriter("sin_cos.jld2")
    println("""Run `DataWatcher.watch("sin_cos.jld2")` in the Julia REPL""")
    println("Ctl-C to stop data generation")
    while true
        try
            writer(sin(x), "sin x")
            writer(cos(x), "cos x")
            sleep(0.1)
            x += 0.1
        catch ex
            if isa(ex, InterruptException)
                break
            end
            throw(ex)
        end
    end
end
