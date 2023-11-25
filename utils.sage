def log2_strict(n):
	logn = log(n, 2).n()
	assert logn.is_integer()
	return int(logn)

def two_adic_generator(field, bits):
	two_adicity = dict(factor(field.order() - 1))[2]
	assert bits <= two_adicity, f'need two-adicity of {bits} but have {two_adicity}'
	g = field.multiplicative_generator()
	return g^((field.order()-1)/(2^bits))

def two_adic_subgroup(field, bits, shift=1):
	g = two_adic_generator(field, bits)
	return [shift*g^i for i in range(2^bits)]
