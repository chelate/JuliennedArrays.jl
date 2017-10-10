struct JulienneIndexer{T, N, IS, ID} <: AbstractArray{T, N}
    indexes::IS
    indexed::ID
end

indices(j::JulienneIndexer) = getindex_unrolled(j.indexes, j.indexed)
size(j::JulienneIndexer) = length.(indices(j))
getindex(j::JulienneIndexer{T, N}, index::Vararg{Int, N}) where {T, N} =
    setindex_unrolled(j.indexes, index, j.indexed)

JulienneIndexer(indexes::IS, indexed::ID) where {IS, ID} =
    JulienneIndexer{
        typeof(setindex_unrolled(indexes, 1, indexed)),
        length(getindex_unrolled(indexes, indexed)),
        IS, ID}(indexes, indexed)

find_unrolled(t) = find_unrolled(t, 1)
find_unrolled(t::Tuple{}, n) = ()
find_unrolled(t, n) = begin
    next = find_unrolled(Base.tail(t), n + 1)
    ifelse(first(t), (n, next...), next)
end

drop_tuple(t::Tuple{A}) where A = first(t)
drop_tuple(t) = t

colon_dimensions(j::JulienneIndexer) =
    drop_tuple(find_unrolled(.!(j.indexed)))

is_indexed(::typeof(*)) = True()
is_indexed(::typeof(:)) = False()

export julienne
"""
    julienne(T, array, code)
    julienne(T, array, code, swap)

Slice an array and create shares of type `T`. `T` should be one of `Arrays`,
`Swaps`, or `Views`. The code should a tuple of length `ndims(array)`, where `:`
indicates an axis parallel to slices and `*` indices an axis perpendicular to
slices.

```jldoctest
julia> using JuliennedArrays

julia> code = (*, :);

julia> array = [5 6 4; 1 3 2; 7 9 8]
3×3 Array{Int64,2}:
 5  6  4
 1  3  2
 7  9  8

julia> arrays = julienne(Arrays, array, (*, :));

julia> map(sum, arrays)
3-element Array{Int64,1}:
 15
  6
 24

julia> views = julienne(Views, array, (*, :));

julia> map(sum, views)
3-element Array{Int64,1}:
 15
  6
 24

julia> swaps = julienne(Swaps, array, (*, :));

julia> map(sum, swaps)
3-element Array{Int64,1}:
 15
  6
 24
```
"""
julienne(T, array, code) =
    T(array, JulienneIndexer(indices(array), is_indexed.(code)))

export align
"""
    align(slices, code)

Align an array of slices into a larger array. Code should be a tuple for each
dimension of the desired output. Slices will slide into dimensions coded by `:`,
while `*` indicates dimensions taken up by the container array. Each slice
should be EXACTLY the same size.

```jldoctest
julia> using JuliennedArrays, MappedArrays

julia> code = (*, :);

julia> array = [5 6 4; 1 3 2; 7 9 8]
3×3 Array{Int64,2}:
 5  6  4
 1  3  2
 7  9  8

julia> swaps = julienne(Swaps, array, code);

julia> align(mappedarray(sort, swaps), code)
3×3 Array{Int64,2}:
 4  5  6
 1  2  3
 7  8  9
```
"""
function align(input_slices::AbstractArray{<: AbstractArray}, code)
    indexed = is_indexed.(code)

    first_input_slice = first(input_slices)

    trivial = Base.OneTo(1)

    output_indexes =
        setindex_unrolled(
            setindex_unrolled(
                indexed,
                indices(input_slices),
                indexed,
                trivial),
            indices(first_input_slice),
            .!indexed,
            trivial
        )

    output = similar(first_input_slice, output_indexes...)
    output_slices = julienne(Arrays, output, code)

    output_slices[1] = first_input_slice
    for i in Iterators.Drop(eachindex(input_slices), 1)
        output_slices[i] = input_slices[i]
    end
    output
end