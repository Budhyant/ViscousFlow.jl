## Field data macros

"""
    @griddata(wrapper,nctypes)

Create a basic set of constructors and functions for grid data wrapper type
`wrapper`. The argument `nctypes` is the number of cell types used
to parameterize this grid data type.
"""
macro griddata(wrapper, nctypes)

  ctype = Symbol[]
  for i in 1:eval(nctypes)
    push!(ctype,Symbol("C",string(i)))
  end

  return esc(quote

    export $wrapper

    celltype(::$wrapper{C}) where {C<:CellType} = C

    # This allows easy construction from existing GridData on the same grid.
    $wrapper(C, ::GridData{NX,NY,T};dtype=T) where {NX, NY,T <: Number} = $wrapper(C, (NX, NY),dtype=dtype )

    $wrapper(C, nx::Int, ny::Int;dtype=Float64) = $wrapper(C,(nx,ny),dtype=dtype)
    (::Type{$wrapper{$(ctype...),NX,NY,T,DT}})() where {$(ctype...),NX,NY,T,DT} =
                  $wrapper($(ctype[1]), (NX, NY),dtype=T)

    # This constructor might be problematic? Introduced only because we have not
    # yet updated the regularization routines for the new GridData parameterization
    (::Type{$wrapper{$(ctype...),NX,NY,T}})() where {$(ctype...),NX,NY,T} =
                  $wrapper($(ctype[1]), (NX, NY),dtype=T)

    Base.similar(::$wrapper{$(ctype...),NX,NY,T,DT};element_type=T) where {$(ctype...),NX,NY,T,DT} =
                  $wrapper($(ctype[1]), (NX, NY),dtype=element_type)

    Base.parent(A::$wrapper) = A.data
    Base.size(A::$wrapper) = size(A.data)
    Base.parentindices(A::$wrapper) = parentindices(A.data)

    @propagate_inbounds Base.getindex(A::$wrapper,i::Int) = getindex(A.data,i)
    @propagate_inbounds Base.setindex!(A::$wrapper, v, i::Int) = setindex!(A.data,convert(eltype(A.data),v),i)

  end)

end

"""
    @wrapparay(wrapper,field,N)

Basic macro to develop any AbstractArray data type into a proper wrapper, with
indexing and other array-type operations.
"""
macro wraparray(wrapper, field, N)
    S = eval(wrapper)
    @assert S <: AbstractArray "Wrapped type must be a subtype of AbstractArray"
    while supertype(S) <: AbstractArray
        S = supertype(S)
    end
    #T = supertype(eval(wrapper))
    #@assert T <: AbstractArray "Wrapped type must be a subtype of AbstractArray"
    #el_type, N = S.parameters

    quote
        Base.parent(A::$wrapper) = A.$field
        Base.size(A::$wrapper) = size(A.$field)
        parentindices(A::$wrapper) = parentindices(A.$field)

        if $N > 1
          function Base.show(io::IO, m::MIME"text/plain", A::$wrapper)
            println(io, "$(typeof(A)) data")
            println(io, "Printing in grid orientation (lower left is (1,1))")
            show(io,m, reverse(transpose(A.$field),dims=1))
          end
          #function Base.summary(io::IO, A::$wrapper)
          #  println(io, "$(typeof(A)) data")
          #  print(io, "Printing in grid orientation (lower left is (1,1))")
          #end
        end

        @propagate_inbounds Base.getindex(A::$wrapper, i::Int) = A.$field[i]
        @propagate_inbounds Base.setindex!(A::$wrapper, v, i::Int) = A.$field[i] = convert(eltype(A.$field), v)
        if $N > 1
          @propagate_inbounds Base.getindex(A::$wrapper, I::Vararg{Int, $N}) = A.$field[I...]
          @propagate_inbounds Base.setindex!(A::$wrapper, v, I::Vararg{Int, $N}) = A.$field[I...] = convert(eltype(A.$field), v)
        end
    end
end
