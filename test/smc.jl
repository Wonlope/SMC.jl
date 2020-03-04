using DSGE, ModelConstructors, HDF5, Random, JLD2, FileIO, Plots

path = dirname(@__FILE__)
writing_output = false

m = AnSchorfheide()

save = normpath(joinpath(dirname(@__FILE__),"save"))
m <= Setting(:saveroot, save)

data = h5read("reference/smc.h5", "data")

m <= Setting(:n_particles, 400)
m <= Setting(:n_Φ, 100)
m <= Setting(:λ, 2.0)
m <= Setting(:n_smc_blocks, 1)
m <= Setting(:use_parallel_workers, true)
m <= Setting(:step_size_smc, 0.5)
m <= Setting(:n_mh_steps_smc, 1)
m <= Setting(:resampler_smc, :polyalgo)
m <= Setting(:target_accept, 0.25)

m <= Setting(:mixture_proportion, .9)
m <= Setting(:adaptive_tempering_target_smc, false)
m <= Setting(:resampling_threshold, .5)
m <= Setting(:smc_iteration, 0)
m <= Setting(:use_chand_recursion, true)

@everywhere Random.seed!(42)
#=
println("Estimating AnSchorfheide Model... (approx. 2 minutes)")
DSGE.smc2(m, data, verbose = :none) # us.txt gives equiv to periods 95:174 in our current dataset
println("Estimation done!")

test_file = load(rawpath(m, "estimate", "smc_cloud.jld2"))
test_cloud  = test_file["cloud"]
test_w      = test_file["w"]
test_W      = test_file["W"]

if writing_output
    jldopen("reference/smc_cloud_fix=true.jld2", true, true, true, IOStream) do file
        write(file, "cloud", test_cloud)
        write(file, "w", test_w)
        write(file, "W", test_W)
    end
end

saved_file  = load("reference/smc_cloud_fix=true.jld2")
saved_cloud = saved_file["cloud"]
saved_w     = saved_file["w"]
saved_W     = saved_file["W"]

####################################################################
cloud_fields = fieldnames(typeof(test_cloud))
@testset "ParticleCloud Fields: AnSchorf" begin
    @test @test_matrix_approx_eq SMC.get_vals(test_cloud) SMC.get_vals(saved_cloud)
    @test @test_matrix_approx_eq SMC.get_loglh(test_cloud) SMC.get_loglh(saved_cloud)
    @test length(test_cloud.particles) == length(saved_cloud.particles)
    @test test_cloud.tempering_schedule == saved_cloud.tempering_schedule
    @test test_cloud.ESS ≈ saved_cloud.ESS
    @test test_cloud.stage_index == saved_cloud.stage_index
    @test test_cloud.n_Φ == saved_cloud.n_Φ
    @test test_cloud.resamples == saved_cloud.resamples
    @test test_cloud.c == saved_cloud.c
    @test test_cloud.accept == saved_cloud.accept
end

test_particle  = test_cloud.particles[1,:]
saved_particle = saved_cloud.particles[1,:]
N = length(test_particle)
@testset "Individual Particle Fields Post-SMC: AnSchorf" begin
    @test test_particle[1:SMC.ind_para_end(N)] ≈ saved_particle[1:SMC.ind_para_end(N)]
    @test test_particle[SMC.ind_loglh(N)]      ≈ saved_particle[SMC.ind_loglh(N)]
    @test test_particle[SMC.ind_logpost(N)]    ≈ saved_particle[SMC.ind_logpost(N)]
    @test test_particle[SMC.ind_logprior(N)]   ≈ saved_particle[SMC.ind_logprior(N)]
    @test test_particle[SMC.ind_old_loglh(N)] == saved_particle[SMC.ind_old_loglh(N)]
    @test test_particle[SMC.ind_accept(N)]    == saved_particle[SMC.ind_accept(N)]
    @test test_particle[SMC.ind_weight(N)]     ≈ saved_particle[SMC.ind_weight(N)]
end

@testset "Weight Matrices: AnSchorf" begin
    @test @test_matrix_approx_eq test_w saved_w
    @test @test_matrix_approx_eq test_W saved_W
end
=#
####################################################################
# Bridging Test
####################################################################
m = AnSchorfheide()

save = normpath(joinpath(dirname(@__FILE__),"save"))
m <= Setting(:saveroot, save)

data = h5read("reference/smc.h5", "data")

m <= Setting(:n_particles, 400)
m <= Setting(:n_Φ, 100)
m <= Setting(:λ, 2.0)
m <= Setting(:n_smc_blocks, 1)
m <= Setting(:use_parallel_workers, true)
m <= Setting(:step_size_smc, 0.5)
m <= Setting(:n_mh_steps_smc, 1)
m <= Setting(:resampler_smc, :polyalgo)
m <= Setting(:target_accept, 0.25)

m <= Setting(:mixture_proportion, .9)
m <= Setting(:adaptive_tempering_target_smc, false)
m <= Setting(:resampling_threshold, .5)
m <= Setting(:smc_iteration, 0)
m <= Setting(:use_chand_recursion, true)

@everywhere Random.seed!(42)

# Estimate with 1st half of sample
m_old = deepcopy(m)
m_old <= Setting(:n_particles, 600, true, "npart", "") #1000)
m_old <= Setting(:data_vintage, "000000")
#DSGE.smc2(m_old, data[:,1:Int(floor(end/2))], verbose = :low)

m_new = deepcopy(m)

# Estimate with 2nd half of sample
m_new <= Setting(:data_vintage, "200218")
m_new <= Setting(:tempered_update_prior_weight, .5)
m_new <= Setting(:tempered_update, true)
m_new <= Setting(:n_particles, 600, true, "npart", "")

old_vint = "000000"
m_new <= Setting(:previous_data_vintage, old_vint)

loadpath = rawpath(m_old, "estimate", "smc_cloud.jld2")
loadpath = replace(loadpath, "vint=[0-9]{6}" => "vint=" * old_vint)

old_cloud = ParticleCloud(load(loadpath, "cloud"), map(x -> x.key, m.parameters))
m_new <= Setting(:n_particles, 600, true, "npart", "")
DSGE.smc2(m_new, data, old_data = data[:,1:Int(floor(end/2))],
          old_cloud = old_cloud, save_intermediate = true, intermediate_stage_increment = 1)

#=loadpath = rawpath(m_new, "estimate", "smc_cloud.jld2")
loadpath = replace(loadpath, "vint=[0-9]{6}" => "vint=200218")

for i in 1:64
    cloud = load(replace(loadpath, ".jld" => "_stage=$(i).jld"), "cloud")
    histogram(cloud.particles[:, 1])
end=#

#error()
