extends RefCounted
## Merging procedural prop parts into one vertex-coloured surface.
##
## Every prop here is built in code and merged to a single mesh — one draw call
## each, with the part colours carried as vertex colours. The benchmark
## (tools/perf_test.sh) is why: multi-mesh props put the flora at ~1357 draw calls
## a frame. This is the one implementation of that merge; world/boat.gd and
## world/bench.gd both call it, so a fix lands in both.
##
## **Never use SurfaceTool.append_from() for this.** append_from copies the *source*
## mesh's own arrays and ignores a colour staged with set_color(), so the merged
## surface ends up with no usable vertex colours and — with
## vertex_color_use_as_albedo — renders black; it stays black even in daylight if the
## source also lacks a NORMAL array. Hence the vertex-by-vertex walk below.

## parts: [[Mesh, Transform3D, Color], ...] -> one surface with vertex colours.
## Each part's arrays are read out, transformed and re-emitted with the part's
## colour (SurfaceTool's set_* calls are sticky until changed).
static func merge(parts: Array) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		var src: Mesh = part[0]
		var xform: Transform3D = part[1]
		var colour: Color = part[2]
		var arrays := src.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var count := indices.size() if indices.size() > 0 else verts.size()
		st.set_color(colour)
		for i in count:
			var vi: int = indices[i] if indices.size() > 0 else i
			st.set_normal(xform.basis * normals[vi])
			if uvs.size() > vi:
				st.set_uv(uvs[vi])
			st.add_vertex(xform * verts[vi])
	return st.commit()


static func paint() -> StandardMaterial3D:
	## The material a merged prop wants: albedo straight from the vertex colours.
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.8
	return m