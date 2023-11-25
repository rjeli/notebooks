def log2_strict(n):
	logn = log(n, 2).n()
	assert logn.is_integer()
	return int(logn)