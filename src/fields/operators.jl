include("lgf.jl")
include("convolution.jl")

import Base: *, \, A_mul_B!, A_ldiv_B!

# laplacian

function laplacian!(out::Nodes{Dual,NX, NY}, w::Nodes{Dual,NX, NY}) where {NX, NY}
    @inbounds for y in 2:NY-1, x in 2:NX-1
        out[x,y] = w[x,y-1] + w[x-1,y] - 4w[x,y] + w[x+1,y] + w[x,y+1]
    end
    out
end

function laplacian!(out::Nodes{Primal,NX, NY}, w::Nodes{Primal,NX, NY}) where {NX, NY}
    @inbounds for y in 2:NY-2, x in 2:NX-2
        out[x,y] = w[x,y-1] + w[x-1,y] - 4w[x,y] + w[x+1,y] + w[x,y+1]
    end
    out
end

function laplacian!(out::Edges{Dual,NX, NY}, w::Edges{Dual,NX, NY}) where {NX, NY}
  @inbounds for y in 2:NY-3, x in 2:NX-2
      out.u[x,y] = w.u[x,y-1] + w.u[x-1,y] - 4w.u[x,y] + w.u[x+1,y] + w.u[x,y+1]
  end
  @inbounds for y in 2:NY-2, x in 2:NX-3
      out.v[x,y] = w.v[x,y-1] + w.v[x-1,y] - 4w.v[x,y] + w.v[x+1,y] + w.v[x,y+1]
  end
  out
end

function laplacian!(out::Edges{Primal,NX, NY}, w::Edges{Primal,NX, NY}) where {NX, NY}
  @inbounds for y in 2:NY-2, x in 2:NX-1
      out.u[x,y] = w.u[x,y-1] + w.u[x-1,y] - 4w.u[x,y] + w.u[x+1,y] + w.u[x,y+1]
  end
  @inbounds for y in 2:NY-1, x in 2:NX-2
      out.v[x,y] = w.v[x,y-1] + w.v[x-1,y] - 4w.v[x,y] + w.v[x+1,y] + w.v[x,y+1]
  end
  out
end

function laplacian(w::Nodes{T,NX,NY}) where {T<:CellType,NX,NY}
  laplacian!(Nodes(T,(NX,NY)), w)
end

function laplacian(w::Edges{T,NX,NY}) where {T<:CellType,NX,NY}
  laplacian!(Edges(T,(NX,NY)), w)
end

### To be removed
function laplacian(w::DualNodes{NX, NY}) where {NX, NY}
    laplacian!(DualNodes(NX, NY), w)
end
###

struct Laplacian{NX, NY, R}
    conv::Nullable{CircularConvolution{NX, NY}}
end

function Laplacian(dims::Tuple{Int,Int};
                   with_inverse = false, fftw_flags = FFTW.ESTIMATE)
    NX, NY = dims
    if !with_inverse
        return Laplacian{NX, NY, false}(Nullable())
    end

    G = view(LGF_TABLE, 1:NX, 1:NY)
    Laplacian{NX, NY, true}(Nullable(CircularConvolution(G, fftw_flags)))
end

function Laplacian(nx::Int, ny::Int; with_inverse = false, fftw_flags = FFTW.ESTIMATE)
    Laplacian((nx, ny), with_inverse = with_inverse, fftw_flags = fftw_flags)
end

function Base.show(io::IO, L::Laplacian{NX, NY, R}) where {NX, NY, R}
    nodedims = "(nx = $NX, ny = $NY)"
    inverse = R ? " (and inverse)" : ""
    print(io, "Discrete Laplacian$inverse on a $nodedims grid")
end

A_mul_B!(out::Nodes{Dual,NX,NY}, L::Laplacian, s::Nodes{Dual,NX,NY}) where {NX,NY} = laplacian!(out, s)
L::Laplacian * s::Nodes{Dual,NX,NY} where {NX,NY} = laplacian(s)

function A_ldiv_B!(out::Nodes{Dual,NX, NY},
                   L::Laplacian{NX, NY, true},
                   s::Nodes{Dual, NX, NY}) where {NX, NY}

    A_mul_B!(out.data, get(L.conv), s.data)
    out
end
L::Laplacian \ s::Nodes{Dual,NX,NY} where {NX,NY} = A_ldiv_B!(Nodes(Dual,size(s)), L, s)

# curl
function curl!(edges::Edges{Primal, NX, NY},
               s::Nodes{Dual,NX, NY}) where {NX, NY}

    @inbounds for y in 1:NY-1, x in 1:NX
        edges.u[x,y] = s[x,y+1] - s[x,y]
    end

    @inbounds for y in 1:NY, x in 1:NX-1
        edges.v[x,y] = s[x,y] - s[x+1,y]
    end
    edges
end

curl(nodes::Nodes{Dual,NX,NY}) where {NX,NY} = curl!(Edges(Primal, nodes), nodes)

function curl!(nodes::Nodes{Dual,NX, NY},
               edges::Edges{Primal, NX, NY}) where {NX, NY}

    u, v = edges.u, edges.v
    @inbounds for y in 2:NY-1, x in 2:NX-1
        nodes[x,y] = u[x,y-1] - u[x,y] - v[x-1,y] + v[x,y]
    end
    nodes
end

function curl(edges::Edges{Primal, NX, NY}) where {NX, NY}
    curl!(Nodes(Dual,(NX, NY)), edges)
end

# divergence

function divergence!(nodes::Nodes{Primal, NX, NY},
                     edges::Edges{Primal, NX, NY}) where {NX, NY}

    u, v = edges.u, edges.v

    @inbounds for y in 1:NY-1, x in 1:NX-1
        nodes[x,y] = - u[x,y] + u[x+1,y] - v[x,y] + v[x,y+1]
    end
    nodes
end

function divergence!(nodes::Nodes{Dual, NX, NY},
                     edges::Edges{Dual, NX, NY}) where {NX, NY}

    u, v = edges.u, edges.v

    @inbounds for y in 2:NY-1, x in 2:NX-1
        nodes[x,y] = - u[x-1,y-1] + u[x,y-1] - v[x-1,y-1] + v[x-1,y]
    end
    nodes
end

function divergence(edges::Edges{T, NX, NY}) where {T <: CellType, NX, NY}
    divergence!(Nodes(T, NX, NY), edges)
end

# grad
function gradient!(edges::Edges{Primal, NX, NY},
                     p::Nodes{Primal, NX, NY}) where {NX, NY}

    @inbounds for y in 1:NY-1, x in 2:NX-1
        edges.u[x,y] = - p[x-1,y] + p[x,y]
    end
    @inbounds for y in 2:NY-1, x in 1:NX-1
        edges.v[x,y] = - p[x,y-1] + p[x,y]
    end
    edges
end

function gradient(p::Nodes{Primal, NX, NY}) where {NX, NY}
  gradient!(Edges(Primal,(NX,NY)),p)
end


function gradient!(d::EdgeGradient{Primal, Dual, NX, NY},
                     edges::Edges{Primal, NX, NY}) where {NX, NY}

    @inbounds for y in 1:NY-1, x in 1:NX-1
        d.dudx[x,y] = - edges.u[x,y] + edges.u[x+1,y]
        d.dvdy[x,y] = - edges.v[x,y] + edges.v[x,y+1]
    end
    @inbounds for y in 2:NY-1, x in 2:NX-1
        d.dudy[x,y] = - edges.u[x,y-1] + edges.u[x,y]
        d.dvdx[x,y] = - edges.v[x-1,y] + edges.v[x,y]
    end
    d
end

function gradient!(d::EdgeGradient{Dual, Primal, NX, NY},
                     edges::Edges{Dual, NX, NY}) where {NX, NY}

    @inbounds for y in 2:NY-1, x in 2:NX-1
        d.dudx[x,y] = - edges.u[x-1,y] + edges.u[x,y]
        d.dvdy[x,y] = - edges.v[x,y-1] + edges.v[x,y]
    end
    @inbounds for y in 1:NY-1, x in 1:NX-1
        d.dudy[x,y] = - edges.u[x,y] + edges.u[x,y+1]
        d.dvdx[x,y] = - edges.v[x,y] + edges.v[x+1,y]
    end
    d
end

function gradient(edges::Edges{C, NX, NY}) where {C<:CellType,NX,NY}
  gradient!(EdgeGradient(C,(NX,NY)),edges)
end

#### to be removed
function curl!(edges::Edges{Primal, NX, NY},
               s::DualNodes{NX, NY}) where {NX, NY}

    @inbounds for y in 1:NY-1, x in 1:NX
        edges.u[x,y] = s[x,y+1] - s[x,y]
    end

    @inbounds for y in 1:NY, x in 1:NX-1
        edges.v[x,y] = s[x,y] - s[x+1,y]
    end
    edges
end

curl(nodes::DualNodes) = curl!(Edges(Primal, nodes), nodes)

function curl!(nodes::DualNodes{NX, NY},
               edges::Edges{Primal, NX, NY}) where {NX, NY}

    u, v = edges.u, edges.v
    @inbounds for y in 2:NY-1, x in 2:NX-1
        nodes[x,y] = u[x,y-1] - u[x,y] - v[x-1,y] + v[x,y]
    end
    nodes
end

#function curl(edges::Edges{Primal, NX, NY}) where {NX, NY}
#    curl!(DualNodes(NX, NY), edges)
#end


function divergence!(nodes::DualNodes{NX, NY},
                     edges::Edges{Dual, NX, NY}) where {NX, NY}

    u, v = edges.u, edges.v

    @inbounds for y in 2:NY-1, x in 2:NX-1
        nodes[x,y] = - u[x-1,y-1] + u[x,y-1] - v[x-1,y-1] + v[x-1,y]
    end
    nodes
end

#function divergence(edges::Edges{Dual, NX, NY}) where {NX, NY}
#    divergence!(DualNodes(NX, NY), edges)
#end

#####
