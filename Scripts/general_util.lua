function clamp(mx, mn, t)
	if t > mx then return mx end
	if t < mn then return mn end
	return t
end

-----------------------------------------------------------------------------------------------

function Reflect (v,n)
    return v - n*2*(v:dot(n))
end
